import requests
import time
import random

# 1. Configuration
BASE_URL = "http://127.0.0.1:8000"
PHONE_NUMBER = "8240680751"  # Use a registered phone number
PASSWORD = "anubhav45"
ALERT_ID = 1                 # The ID of the active SOS alert

def get_token():
    """Logs in to get the JWT access token."""
    login_data = {"username": PHONE_NUMBER, "password": PASSWORD}
    response = requests.post(f"{BASE_URL}/users/login", data=login_data)
    if response.status_code == 200:
        return response.json()["access_token"]
    else:
        print("Login failed! Check your credentials.")
        return None

def send_location(token):
    """Simulates moving and sending GPS coordinates."""
    headers = {"Authorization": f"Bearer {token}"}
    
    # Starting coordinates (e.g., Delhi)
    lat, lon = 28.6139, 77.2090

    print("🚀 Starting real-time location simulation...")
    try:
        while True:
            # Simulate small movement
            lat += random.uniform(-0.0001, 0.0001)
            lon += random.uniform(-0.0001, 0.0001)
            
            payload = {"latitude": lat, "longitude": lon}
            
            # Send to the /alerts/{alert_id}/location endpoint
            response = requests.post(
                f"{BASE_URL}/alerts/{ALERT_ID}/location", 
                json=payload, 
                headers=headers
            )
            
            if response.status_code == 200:
                print(f"📍 Sent: {lat:.4f}, {lon:.4f} | Status: Success")
            else:
                print(f"❌ Failed to send location: {response.text}")
            
            time.sleep(3)  # Wait 3 seconds before next update
    except KeyboardInterrupt:
        print("\n🛑 Simulation stopped.")

if __name__ == "__main__":
    token = get_token()
    if token:
        send_location(token)