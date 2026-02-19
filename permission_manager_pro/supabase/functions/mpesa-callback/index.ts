import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
    const supabaseClient = createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    let callbackData: any;
    try {
        callbackData = await req.json()
        console.log("M-Pesa Callback Payload:", JSON.stringify(callbackData))

        const body = callbackData?.Body
        const stkCallback = body?.stkCallback

        if (!stkCallback) {
            throw new Error("Invalid payload: Body.stkCallback missing")
        }

        const result_code = stkCallback.ResultCode
        const result_desc = stkCallback.ResultDesc
        const checkout_request_id = stkCallback.CheckoutRequestID

        let status = result_code === 0 ? 'completed' : 'failed'
        if (result_code === 1032) status = 'cancelled'

        let receipt = null
        let transaction_date = null

        if (result_code === 0 && stkCallback.CallbackMetadata?.Item) {
            const items = stkCallback.CallbackMetadata.Item
            receipt = items.find((i: any) => i.Name === 'MpesaReceiptNumber')?.Value
            const rawDate = items.find((i: any) => i.Name === 'TransactionDate')?.Value?.toString()

            if (rawDate && rawDate.length >= 14) {
                // Convert YYYYMMDDHHmmss to ISO
                transaction_date = `${rawDate.slice(0, 4)}-${rawDate.slice(4, 6)}-${rawDate.slice(6, 8)}T${rawDate.slice(8, 10)}:${rawDate.slice(10, 12)}:${rawDate.slice(12, 14)}Z`
            }
        }

        console.log(`Processing ${status} payment: ${checkout_request_id}`)

        // Invoke SQL handler
        const { error } = await supabaseClient.rpc('handle_mpesa_callback', {
            p_checkout_request_id: checkout_request_id,
            p_status: status,
            p_receipt: receipt,
            p_result_desc: result_desc,
            p_callback_response: callbackData,
            p_transaction_date: transaction_date
        })

        if (error) {
            console.error("Database Update Error:", error)
            await supabaseClient.from('error_logs').insert({
                error_message: `RPC error: ${error.message}`,
                context: `mpesa-callback: ${checkout_request_id}`
            })
            throw error
        }

        return new Response(JSON.stringify({ received: true }), {
            headers: { "Content-Type": "application/json" },
            status: 200,
        })

    } catch (err: any) {
        console.error("Critical Callback Error:", err.message)

        // Final attempt to log parsing error
        await supabaseClient.from('error_logs').insert({
            error_message: `Edge Function Error: ${err.message}`,
            context: 'mpesa-callback: parsing'
        }).catch(() => { })

        return new Response(JSON.stringify({ error: err.message }), {
            headers: { "Content-Type": "application/json" },
            status: 400,
        })
    }
})
