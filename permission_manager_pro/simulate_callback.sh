#!/bin/bash

# Configuration
CALLBACK_URL="https://crpqyicmtufschjukrst.supabase.co/functions/v1/mpesa-callback"

# Generate CheckoutRequestID automatically
CHECKOUT_ID="ws_CO_$(date +%s%N)"

echo "----------------------------------------"
echo "Generated CheckoutRequestID: $CHECKOUT_ID"
echo "----------------------------------------"

# Build payload
PAYLOAD=$(cat <<EOF
{
  "Body": {
    "stkCallback": {
      "MerchantRequestID": "SIMULATED_MERCHANT",
      "CheckoutRequestID": "$CHECKOUT_ID",
      "ResultCode": 0,
      "ResultDesc": "The service request is processed successfully.",
      "CallbackMetadata": {
        "Item": [
          { "Name": "Amount", "Value": 1.0 },
          { "Name": "MpesaReceiptNumber", "Value": "SIMULATED_$(date +%s)" },
          { "Name": "TransactionDate", "Value": $(date +%Y%m%d%H%M%S) },
          { "Name": "PhoneNumber", "Value": 254700000000 }
        ]
      }
    }
  }
}
EOF
)

echo "Sending callback..."

# Send request
curl -X POST "$CALLBACK_URL" \
     -H "Content-Type: application/json" \
     -d "$PAYLOAD"

echo ""
echo "----------------------------------------"
echo "DONE"
echo "----------------------------------------"
