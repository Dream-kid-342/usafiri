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
        // 1. Initialize Supabase Client
        const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
        const supabaseKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
        const supabase = createClient(supabaseUrl, supabaseKey);

        // 2. Parse Request
        const { phoneNumber, amount, userId, accountReference } = await req.json()

        if (!phoneNumber || !amount || !userId) {
            throw new Error('Missing required fields: phoneNumber, amount, userId')
        }

        // 3. Get Credentials
        const env = Deno.env.get('MPESA_ENVIRONMENT') || 'sandbox'; // sandbox or production
        const isProd = env === 'production';

        const consumerKey = isProd ? Deno.env.get('MPESA_CONSUMER_KEY_PROD') : Deno.env.get('MPESA_CONSUMER_KEY_SANDBOX');
        const consumerSecret = isProd ? Deno.env.get('MPESA_CONSUMER_SECRET_PROD') : Deno.env.get('MPESA_CONSUMER_SECRET_SANDBOX');
        const passkey = isProd ? Deno.env.get('MPESA_PASSKEY_PROD') : Deno.env.get('MPESA_PASSKEY_SANDBOX');
        const shortcode = isProd ? Deno.env.get('MPESA_SHORTCODE_PROD') : Deno.env.get('MPESA_SHORTCODE_SANDBOX');
        const callbackUrl = Deno.env.get('MPESA_CALLBACK_URL'); // Ensure this is set in Supabase Secrets

        if (!consumerKey || !consumerSecret || !passkey || !shortcode || !callbackUrl) {
            throw new Error(`Missing M-Pesa Configuration for ${env}`);
        }

        // 4. Generate Access Token
        const auth = btoa(`${consumerKey}:${consumerSecret}`);
        const authUrl = isProd
            ? 'https://api.safaricom.co.ke/oauth/v1/generate?grant_type=client_credentials'
            : 'https://sandbox.safaricom.co.ke/oauth/v1/generate?grant_type=client_credentials';

        const tokenResp = await fetch(authUrl, { headers: { 'Authorization': `Basic ${auth}` } });
        const tokenData = await tokenResp.json();

        if (!tokenData.access_token) {
            throw new Error('Failed to generate M-Pesa Access Token');
        }

        const accessToken = tokenData.access_token;

        // 5. Generate Password & Timestamp
        const date = new Date();
        const timestamp = date.getFullYear().toString() +
            (date.getMonth() + 1).toString().padStart(2, '0') +
            date.getDate().toString().padStart(2, '0') +
            date.getHours().toString().padStart(2, '0') +
            date.getMinutes().toString().padStart(2, '0') +
            date.getSeconds().toString().padStart(2, '0');

        const password = btoa(`${shortcode}${passkey}${timestamp}`);

        // 6. Initiate STK Push
        const stkUrl = isProd
            ? 'https://api.safaricom.co.ke/mpesa/stkpush/v1/processrequest'
            : 'https://sandbox.safaricom.co.ke/mpesa/stkpush/v1/processrequest';

        // Format phone: 07xx -> 2547xx, +254 -> 254
        let formattedPhone = phoneNumber.replace('+', '').replace(/\s/g, '');
        if (formattedPhone.startsWith('0')) formattedPhone = '254' + formattedPhone.substring(1);

        const stkBody = {
            "BusinessShortCode": shortcode,
            "Password": password,
            "Timestamp": timestamp,
            "TransactionType": "CustomerPayBillOnline", // or CustomerBuyGoodsOnline
            "Amount": Math.floor(Number(amount)), // Must be integer
            "PartyA": formattedPhone,
            "PartyB": shortcode,
            "PhoneNumber": formattedPhone,
            "CallBackURL": callbackUrl,
            "AccountReference": accountReference || "Ref",
            "TransactionDesc": "Payment"
        };

        console.log("Initiating STK Push to:", formattedPhone);

        const stkResp = await fetch(stkUrl, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${accessToken}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(stkBody)
        });

        const stkData = await stkResp.json();
        console.log("STK Response:", stkData);

        if (stkData.ResponseCode !== "0") {
            throw new Error(`M-Pesa Error: ${stkData.errorMessage || 'Unknown Error'}`);
        }

        // 7. Log to Database (Pending)
        await supabase.from('payments').insert({
            user_id: userId,
            phone: formattedPhone,
            amount: amount,
            checkout_request_id: stkData.CheckoutRequestID,
            merchant_request_id: stkData.MerchantRequestID,
            status: 'PENDING',
            created_at: new Date().toISOString()
        });

        return new Response(
            JSON.stringify(stkData),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
        )

    } catch (error) {
        console.error("Function Error:", error);
        return new Response(
            JSON.stringify({ error: error.message }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
        )
    }
})
