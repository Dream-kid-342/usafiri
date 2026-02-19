import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )

    const { amount, phoneNumber, userId } = await req.json()

    // 1. Get Daraja Token
    const consumerKey = Deno.env.get('DARAJA_CONSUMER_KEY')
    const consumerSecret = Deno.env.get('DARAJA_CONSUMER_SECRET')
    const auth = btoa(`${consumerKey}:${consumerSecret}`)
    
    const tokenRes = await fetch('https://sandbox.safaricom.co.ke/oauth/v1/generate?grant_type=client_credentials', {
      headers: { 'Authorization': `Basic ${auth}` }
    })
    const { access_token } = await tokenRes.json()

    // 2. Initiate STK Push
    const timestamp = new Date().toISOString().replace(/[^0-9]/g, '').slice(0, 14)
    const shortcode = Deno.env.get('DARAJA_SHORTCODE')
    const passkey = Deno.env.get('DARAJA_PASSKEY')
    const password = btoa(`${shortcode}${passkey}${timestamp}`)

    const callbackUrl = `${Deno.env.get('SUPABASE_URL')}/functions/v1/mpesa-callback`

    const stkRes = await fetch('https://sandbox.safaricom.co.ke/mpesa/stkpush/v1/processrequest', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${access_token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        BusinessShortCode: shortcode,
        Password: password,
        Timestamp: timestamp,
        TransactionType: 'CustomerPayBillOnline',
        Amount: amount,
        PartyA: phoneNumber,
        PartyB: shortcode,
        PhoneNumber: phoneNumber,
        CallBackURL: callbackUrl,
        AccountReference: 'PermissionPro',
        TransactionDesc: 'Subscription Payment',
      }),
    })

    const stkData = await stkRes.json()

    // 3. Record Payment Attempt
    if (stkData.ResponseCode === '0') {
        const { error } = await supabaseClient
        .from('payments')
        .insert({
            user_id: userId,
            amount: amount,
            phone: phoneNumber,
            status: 'pending',
            checkout_request_id: stkData.CheckoutRequestID
        })
        if (error) throw error
    }

    return new Response(JSON.stringify(stkData), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
