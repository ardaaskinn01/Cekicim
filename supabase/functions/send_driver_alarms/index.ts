import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { JWT } from 'npm:google-auth-library@9'

Deno.serve(async (req) => {
  try {
    const bodyJson = await req.json()
    const { request_id, driver_ids, notification_type } = bodyJson
    const customTitle = bodyJson.title
    const customBody = bodyJson.body

    if (!request_id || !driver_ids || !Array.isArray(driver_ids)) {
      return new Response(JSON.stringify({ error: 'Missing request_id or driver_ids' }), {
        headers: { 'Content-Type': 'application/json' },
        status: 400,
      })
    }

    // Initialize Supabase Client
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Aynı kullanıcı/token birden fazla kez gelirse tek bildirim gitsin
    const uniqueIds = [...new Set(driver_ids as string[])]

    // Fetch FCM Tokens for the drivers/users
    const { data: profiles, error } = await supabase
      .from('profiles')
      .select('id, fcm_token')
      .in('id', uniqueIds)

    if (error) throw error

    const tokens: string[] = [...new Set(
      profiles
        .map((p: any) => p.fcm_token)
        .filter((t: any) => !!t)
    )] as string[]

    if (tokens.length === 0) {
      return new Response(JSON.stringify({ message: 'No FCM tokens found' }), {
        headers: { 'Content-Type': 'application/json' },
        status: 200,
      })
    }

    let serviceAccountString = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')
    if (!serviceAccountString) {
      throw new Error('FIREBASE_SERVICE_ACCOUNT environment variable is not set')
    }
    
    // Trim spaces and surrounding single/double quotes that might have been added by CLI/OS shell escaping
    serviceAccountString = serviceAccountString.trim();
    if ((serviceAccountString.startsWith("'") && serviceAccountString.endsWith("'")) ||
        (serviceAccountString.startsWith('"') && serviceAccountString.endsWith('"'))) {
      serviceAccountString = serviceAccountString.substring(1, serviceAccountString.length - 1).trim();
    }
    
    console.log("Parsed serviceAccountString length:", serviceAccountString.length)
    console.log("Starts with:", serviceAccountString.substring(0, 15))
    console.log("Ends with:", serviceAccountString.substring(serviceAccountString.length - 15))
    
    const serviceAccount = JSON.parse(serviceAccountString)

    // Get Access Token
    const jwtClient = new JWT({
      email: serviceAccount.client_email,
      key: serviceAccount.private_key,
      scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
    })

    const credentials = await jwtClient.getAccessToken()
    const accessToken = credentials.token

    if (!accessToken) {
      throw new Error('Failed to get Firebase access token')
    }

    const projectId = serviceAccount.project_id
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`

    // Alarm sesiyle çalacak tipler (diğerleri normal bildirim sesi kullanır)
    const alarmTypes = ['NEW_REQUEST', 'VOIP_CALL', 'DRIVER_ARRIVING', 'OFFLINE_DRIVER_REMINDER']
    // Bildirimin geçerlilik süresi (sn): eski alarmlar sonradan çalmasın / birikmesin
    const ttlByType: Record<string, number> = {
      NEW_REQUEST: 90,
      VOIP_CALL: 30,
      DRIVER_ARRIVING: 300,
      OFFLINE_DRIVER_REMINDER: 600,
      REQUEST_TAKEN: 120,
      CHAT_MESSAGE: 3600,
    }

    // Send notification to each token
    const results = await Promise.all(
      tokens.map(async (token: string) => {
        let title = customTitle || 'Yeni Yol Yardım Talebi!'
        let body = customBody || 'Yakınınızda yeni bir çekici talebi var. Detaylar için tıklayın.'
        let type = notification_type || 'NEW_REQUEST'

        if (notification_type === 'REQUEST_TAKEN') {
          title = 'Talep Alındı'
          body = 'İncelediğiniz talep başka bir sürücü tarafından kabul edildi.'
          type = 'REQUEST_TAKEN'
        } else if (notification_type === 'VOIP_CALL') {
          title = customTitle || '📞 Gelen Sesli Arama'
          body = customBody || 'Çekici hizmetiniz için canlı sesli arama geliyor. Cevaplamak için tıklayın.'
          type = 'VOIP_CALL'
        } else if (notification_type === 'OFFLINE_DRIVER_REMINDER') {
          title = 'Yakınında Yolda Kalan Biri Var! 🚨'
          body = 'Yakınında yeni bir çekici talebi oluşturuldu. Çevrimiçi ol ve hemen işi al! 🚜'
          type = 'OFFLINE_DRIVER_REMINDER'
        } else if (notification_type === 'CHAT_MESSAGE') {
          title = customTitle || '💬 Yeni Mesaj'
          body = customBody || 'Yeni bir mesajınız var.'
          type = 'CHAT_MESSAGE'
        } else if (notification_type === 'DRIVER_ARRIVING') {
          title = customTitle || '🚜 Çekiciniz Yaklaştı!'
          body = customBody || 'Çekici aracınız yaklaşık 250 metre mesafede. Lütfen aracınızın başında hazır olun.'
          type = 'DRIVER_ARRIVING'
        }

        const isAlarm = alarmTypes.includes(type)
        const iosSound = isAlarm ? 'alarm.mp3' : 'default'
        const ttl = ttlByType[type] ?? 3600
        // Aynı talep + tip tekrar gelirse cihazda öncekinin yerini alır (birikme yok)
        const collapseId = `${type}_${request_id}`.substring(0, 64)

        // ANDROID: data-only (notification bloğu YOK). Böylece sistem + uygulama
        // iki ayrı bildirim üretmez; ses/kanal istemcide (alarm kanalı) belirlenir.
        // iOS: tek APNs alert (sistem gösterir; istemci iOS'ta yerel kopya üretmez).
        const messageBody = {
          message: {
            token: token,
            data: {
              request_id: String(request_id),
              type: String(type),
              title: title,
              body: body,
            },
            android: {
              priority: 'high',
              collapse_key: collapseId,
              ttl: `${ttl}s`,
            },
            apns: {
              headers: {
                'apns-priority': '10',
                'apns-push-type': 'alert',
                'apns-collapse-id': collapseId,
                'apns-expiration': String(Math.floor(Date.now() / 1000) + ttl),
                // NOT: apns-topic bilinçli olarak YOK. Sürücü bundle id'sini sabitlemek,
                // müşteri uygulaması token'larında push'un reddedilmesine yol açıyordu.
                // FCM, topic'i token'ın ait olduğu uygulamadan kendisi belirler.
              },
              payload: {
                aps: {
                  alert: {
                    title: title,
                    body: body,
                  },
                  sound: iosSound,
                  'thread-id': String(request_id),
                },
              },
            },
          },
        }

        const response = await fetch(fcmUrl, {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(messageBody),
        })

        const resJson = await response.json()
        console.log(`FCM response for token ${token.substring(0, 10)}... :`, JSON.stringify(resJson))

        // Geçersiz/eski token'ı temizle (ölü cihazlara tekrar tekrar gönderim yapılmasın)
        const errCode = resJson?.error?.details?.[0]?.errorCode || resJson?.error?.status
        if (errCode === 'UNREGISTERED' || errCode === 'NOT_FOUND') {
          await supabase.from('profiles').update({ fcm_token: null }).eq('fcm_token', token)
        }
        return resJson
      })
    )

    return new Response(JSON.stringify({ success: true, results }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (err: any) {
    console.error("send_driver_alarms error:", err);
    return new Response(JSON.stringify({ error: err.message || err }), {
      headers: { 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})
