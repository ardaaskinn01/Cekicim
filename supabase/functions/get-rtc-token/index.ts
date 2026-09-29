import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import {
  RtcTokenBuilder,
  RtcRole,
} from "https://esm.sh/agora-token@2.0.3"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { channel_name, uid } = await req.json()

    if (!channel_name || uid === undefined) {
      throw new Error('channel_name ve uid parametreleri zorunludur.')
    }

    const appId = Deno.env.get('AGORA_APP_ID')
    const appCertificate = Deno.env.get('AGORA_APP_CERTIFICATE')

    if (!appId || !appCertificate) {
      throw new Error('AGORA_APP_ID veya AGORA_APP_CERTIFICATE ortam değişkeni tanımlı değil.')
    }

    // Token geçerlilik süresi: 1 saat
    const expirationTimeInSeconds = 3600
    const currentTimestamp = Math.floor(Date.now() / 1000)
    const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds

    const token = RtcTokenBuilder.buildTokenWithUid(
      appId,
      appCertificate,
      channel_name,
      uid,
      RtcRole.PUBLISHER,
      privilegeExpiredTs,
      privilegeExpiredTs,
    )

    return new Response(
      JSON.stringify({ token, appId }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error: any) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
