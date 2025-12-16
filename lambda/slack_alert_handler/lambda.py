import os
import json
import urllib3

http = urllib3.PoolManager()

def lambda_handler(event, context):
    # Get message from SNS
    message = event['Records'][0]['Sns']['Message']
    
    # Slack Bot Token from environment variable
    token = os.environ["SLACK_BOT_TOKEN"]
    channel = "#alerts"  # your channel name

    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }

    payload = {
        "channel": channel,
        "text": f"CloudWatch Alert:\n{message}"
    }

    # POST message to Slack
    response = http.request(
        "POST",
        "https://slack.com/api/chat.postMessage",
        body=json.dumps(payload).encode("utf-8"),
        headers=headers
    )

    resp_data = json.loads(response.data.decode("utf-8"))
    
    # Optional: check Slack API success
    if not resp_data.get("ok"):
        print("Slack API error:", resp_data)

    return {
        "statusCode": response.status,
        "body": json.dumps(resp_data)
    }
