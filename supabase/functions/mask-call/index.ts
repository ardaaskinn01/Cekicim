import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { request_id } = await req.json()

    // Initialize Supabase Client
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ""
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ""
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Fetch request details
    const { data: request, error: reqError } = await supabase
      .from('service_requests')
      .select('customer_id, driver_id')
      .eq('id', request_id)
      .single()

    if (reqError || !request) {
      throw new Error('Talep bulunamadı: ' + reqError?.message)
    }

    // Fetch customer phone from profiles
    const { data: customerProfile, error: custError } = await supabase
      .from('profiles')
      .select('phone')
      .eq('id', request.customer_id)
      .single()

    // Fetch driver phone from profiles
    const { data: driverProfile, error: drvError } = await supabase
      .from('profiles')
      .select('phone')
      .eq('id', request.driver_id)
      .single()

    if (custError || !customerProfile?.phone || drvError || !driverProfile?.phone) {
      throw new Error('Müşteri veya sürücü telefon bilgisi eksik.')
    }

    // Twilio Configuration
    const accountSid = Deno.env.get('TWILIO_ACCOUNT_SID')
    const authToken = Deno.env.get('TWILIO_AUTH_TOKEN')
    const fromNumber = Deno.env.get('TWILIO_FROM_NUMBER') // Virtual mask number

    if (!accountSid || !authToken || !fromNumber) {
      // Fallback for simulation/testing mode if Twilio environment is not set
      console.log(`[SİMÜLASYON] Arama Maskeleme Tetiklendi: ${customerProfile.phone} <-> ${driverProfile.phone}`);
      return new Response(
        JSON.stringify({ success: true, message: 'Arama simülasyonu başlatıldı (Twilio bilgileri eksik).' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Trigger Twilio Call Bridging (Voice Calls API)
    // Call first party (Driver) and connect them to second party (Customer)
    const url = `https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Calls.json`
    const auth = btoa(`${accountSid}:${authToken}`)

    // Create Twilio TwiML instruction to dial the Customer once the Driver answers
    const twiml = `<Response><Dial callerId="${fromNumber}">${customerProfile.phone}</Dial></Response>`

    const body = new URLSearchParams()
    body.append('To', driverProfile.phone)
    body.append('From', fromNumber)
    body.append('Twiml', twiml)

    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Authorization': `Basic ${auth}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: body.toString(),
    })

    if (!response.ok) {
      const errText = await response.text()
      throw new Error('Twilio Arama Hatası: ' + errText)
    }

    const resData = await response.json()
    return new Response(
      JSON.stringify({ success: true, callSid: resData.sid }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error: any) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
