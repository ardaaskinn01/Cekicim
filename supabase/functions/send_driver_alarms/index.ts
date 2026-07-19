import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { JWT } from 'npm:google-auth-library@9'

Deno.serve(async (req) => {
  try {
    const { request_id, driver_ids, notification_type } = await req.json()

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

    // Fetch FCM Tokens for the drivers
    const { data: profiles, error } = await supabase
      .from('profiles')
      .select('id, fcm_token')
      .in('id', driver_ids)

    if (error) throw error

    const tokens = profiles
      .map((p: any) => p.fcm_token)
      .filter((t: any) => !!t)

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

    // Send notification to each token
    const results = await Promise.all(
      tokens.map(async (token: string) => {
        const title = notification_type === 'REQUEST_TAKEN'
          ? 'Talep Alındı'
          : 'Yeni Yol Yardım Talebi!'
        const body = notification_type === 'REQUEST_TAKEN'
          ? 'İncelediğiniz talep başka bir sürücü tarafından kabul edildi.'
          : 'Yakınınızda yeni bir çekici talebi var. Detaylar için tıklayın.'
        const type = notification_type === 'REQUEST_TAKEN'
          ? 'REQUEST_TAKEN'
          : 'NEW_REQUEST'

        const messageBody = {
          message: {
            token: token,
            notification: {
              title: title,
              body: body,
            },
            data: {
              request_id: request_id, // snake_case yapıldı
              type: type,
            },
            android: {
              priority: 'high',
              notification: {
                sound: 'bg_alarm2',
                channelId: 'cekici_alerts_v2',
              },
            },
            apns: {
              headers: {
                'apns-priority': '10',
              },
              payload: {
                aps: {
                  alert: {
                    title: title,
                    body: body,
                  },
                  sound: 'bg_alarm2.mp3',
                  'content-available': 1,
                  'mutable-content': 1,
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
