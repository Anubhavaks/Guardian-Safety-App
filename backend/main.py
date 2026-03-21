from fastapi import FastAPI, Depends, HTTPException
from sqlalchemy.orm import Session
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from jose import JWTError, jwt
from fastapi.middleware.cors import CORSMiddleware
from fastapi import FastAPI, Depends, HTTPException, WebSocket, WebSocketDisconnect
from twilio.rest import Client
import os
from fastapi import FastAPI, Depends, HTTPException, WebSocket, WebSocketDisconnect, File, UploadFile
import shutil
import os
import speech_recognition as sr
from pydub import AudioSegment
import threading

import models
import schemas
import utils
from database import engine, SessionLocal

# 1. Create Tables (Do this once)
models.Base.metadata.create_all(bind=engine)

# 2. Initialize App
app = FastAPI(title="Guardian Safety API")

# --- TWILIO SETUP ---
# Replace these with the actual keys from your Twilio Dashboard
TWILIO_ACCOUNT_SID = "ACa9f31425c4f4b5471468430a5b7d4790"
TWILIO_AUTH_TOKEN = "f4d164b07c92d4b5f7b0cfaa173f14fb"
TWILIO_PHONE_NUMBER = "+19862864233" # Make sure to include the country code, e.g., +1 or +91

# 3. CORS Middleware (Essential for Flutter/Web)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- WEBSOCKET CONNECTION MANAGER ---
class ConnectionManager:
    def __init__(self):
        self.active_connections: list[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        self.active_connections.remove(websocket)

manager = ConnectionManager()

# --- LIVE LOCATION TRACKING ROUTE ---
@app.websocket("/ws/location/{alert_id}")
async def websocket_location_endpoint(websocket: WebSocket, alert_id: int):
    await manager.connect(websocket)
    print(f"\n🟢 LIVE TRACKING INITIATED FOR ALERT ID: {alert_id} 🟢")
    
    try:
        while True:
            # Wait for incoming GPS coordinates from the Flutter app
            data = await websocket.receive_json()
            lat = data.get("latitude")
            lng = data.get("longitude")
            
            # Print the live movement to the terminal
            print(f"📍 [LIVE MOVEMENT - Alert {alert_id}]: Lat {lat}, Lng {lng}")
            
            # (In the future, we can broadcast this to a web dashboard for authorities!)
            
    except WebSocketDisconnect:
        manager.disconnect(websocket)
        print(f"\n🔴 LIVE TRACKING DISCONNECTED FOR ALERT ID: {alert_id} 🔴\n")


# 4. Database Dependency
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# 5. Security Logic
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/users/login")

def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    credentials_exception = HTTPException(
        status_code=401,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, utils.SECRET_KEY, algorithms=[utils.ALGORITHM])
        phone_number: str = payload.get("sub")
        if phone_number is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
    
    user = db.query(models.User).filter(models.User.phone_number == phone_number).first()
    if user is None:
        raise credentials_exception
    return user
@app.get("/")
def read_root():
    return {"message": "Safety App Backend is Running!"}

@app.post("/users/register", response_model=schemas.UserResponse)
def register_user(user: schemas.UserCreate, db: Session = Depends(get_db)):
    # 1. Check if the phone number is already registered
    existing_user = db.query(models.User).filter(models.User.phone_number == user.phone_number).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Phone number already registered")
    
    # 2. Hash the password
    hashed_pwd = utils.hash_password(user.password)
    
    # 3. Create the new user object
    new_user = models.User(
        full_name=user.full_name,
        phone_number=user.phone_number,
        hashed_password=hashed_pwd,
        safe_pin=user.safe_pin
    )
    
    # 4. Save to the database
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    
    return new_user

@app.post("/users/login", response_model=schemas.Token)
def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    # 1. Find the user by phone number (FastAPI's form uses 'username', but we map it to phone_number)
    user = db.query(models.User).filter(models.User.phone_number == form_data.username).first()
    
    # 2. Check if user exists AND password is correct
    if not user or not utils.verify_password(form_data.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="Invalid phone number or password")
    
    # 3. Generate the JWT Token
    access_token = utils.create_access_token(data={"sub": user.phone_number})
    
    # 4. Return the token
    return {"access_token": access_token, "token_type": "bearer"}
@app.post("/contacts/", response_model=schemas.ContactResponse)
def add_contact(contact: schemas.ContactCreate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    # Create the contact and automatically link it to the logged-in user's ID
    new_contact = models.Contact(
        user_id=current_user.id,
        contact_name=contact.contact_name,
        contact_phone=contact.contact_phone
    )
    
    db.add(new_contact)
    db.commit()
    db.refresh(new_contact)
    return new_contact

@app.get("/contacts/", response_model=list[schemas.ContactResponse])
def get_contacts(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    # Fetch only the contacts that belong to the logged-in user
    contacts = db.query(models.Contact).filter(models.Contact.user_id == current_user.id).all()
    return contacts
@app.delete("/contacts/{contact_id}")
def delete_contact(contact_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    # 1. Find the contact, ensuring it belongs to the logged-in user
    contact = db.query(models.Contact).filter(
        models.Contact.id == contact_id, 
        models.Contact.user_id == current_user.id
    ).first()

    # 2. If it doesn't exist (or belongs to someone else), throw an error
    if not contact:
        raise HTTPException(status_code=404, detail="Contact not found")

    # 3. Delete it from the database
    db.delete(contact)
    db.commit()

    print(f"🗑️ CONTACT DELETED: {contact.contact_name} (ID: {contact_id}) by User {current_user.id}")
    return {"message": "Contact deleted successfully"}
@app.post("/alerts/sos", response_model=schemas.AlertResponse)
def trigger_sos(alert: schemas.AlertCreate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    
    # 1. Save the alert with GPS data to the database
    new_alert = models.Alert(
        user_id=current_user.id,
        alert_type=alert.alert_type,
        status="ACTIVE",
        latitude=alert.latitude,
        longitude=alert.longitude
    )
    
    db.add(new_alert)
    db.commit()
    db.refresh(new_alert)
    
    # 2. Fetch all saved emergency contacts for this specific user
    # (Assuming your Contact model is named 'Contact')
    contacts = db.query(models.Contact).filter(models.Contact.user_id == current_user.id).all()
    
    # 3. Generate a clickable Google Maps link
    if alert.latitude and alert.longitude:
        location_link = f"https://www.google.com/maps?q={alert.latitude},{alert.longitude}"
    else:
        location_link = "Location unavailable"
    
    # 4. The Notification Dispatch Engine (REAL SMS)
    print("\n" + "="*60)
    print(f"🚨 SOS TRIGGERED BY: {current_user.full_name} 🚨")
    print(f"Alert ID: {new_alert.id} | Type: {new_alert.alert_type}")
    print(f"📍 Location: {location_link}")
    print("-" * 60)
    
    if not contacts:
        print("⚠️ WARNING: No emergency contacts found! The user is alone.")
    else:
        print("📡 DISPATCHING REAL EMERGENCY SMS...")
        
        # Initialize the Twilio Client
        client = Client(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN)
        
        for contact in contacts:
            message_body = f"🚨 URGENT: {current_user.full_name} has triggered an SOS! Check location: {location_link}"
            
            try:
                # Actually send the text message over the cellular network
                message = client.messages.create(
                    body=message_body,
                    from_=TWILIO_PHONE_NUMBER,
                    to=contact.contact_phone
                )
                print(f"✅ SMS successfully sent to {contact.contact_name} (Message SID: {message.sid})")
                
            except Exception as e:
                # If Twilio fails (e.g. wrong number format), we catch the error 
                # so the backend doesn't crash and the SOS still works!
                print(f"❌ Failed to send SMS to {contact.contact_name}. Error: {e}")
            
    print("="*60 + "\n")
    
    return new_alert

@app.post("/alerts/{alert_id}/cancel", response_model=schemas.AlertResponse)
def cancel_sos(alert_id: int, cancel_req: schemas.AlertCancel, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    # 1. Security Check: Does the PIN match the user's secret PIN?
    if current_user.safe_pin != cancel_req.safe_pin:
        raise HTTPException(status_code=403, detail="Invalid Safe PIN. Cannot cancel alert.")
    
    # 2. Find the active alert in the database
    alert = db.query(models.Alert).filter(models.Alert.id == alert_id, models.Alert.user_id == current_user.id).first()
    
    if not alert:
        raise HTTPException(status_code=404, detail="Alert not found.")
    
    # 3. Update the status to RESOLVED
    alert.status = "RESOLVED"
    db.commit()
    db.refresh(alert)
    
    # 4. Print a confirmation to the terminal
    print("\n" + "="*50)
    print(f"✅ SOS RESOLVED BY: {current_user.full_name} ✅")
    print(f"Alert ID: {alert.id} is now secure.")
    print("="*50 + "\n")
    
    return alert

# --- HEATMAP DATA ROUTE ---
@app.get("/alerts/history/heatmap")
def get_heatmap_data(db: Session = Depends(get_db)):
    # 1. Ask the database for EVERY alert that has valid GPS coordinates
    historical_alerts = db.query(models.Alert).filter(
        models.Alert.latitude.isnot(None),
        models.Alert.longitude.isnot(None)
    ).all()
    
    # 2. Extract just the latitude and longitude into a clean, simple list
    heatmap_points = [
        {"lat": alert.latitude, "lng": alert.longitude} 
        for alert in historical_alerts
    ]
    
    print(f"🗺️ HEATMAP: Swept database. Found {len(heatmap_points)} danger zones.")
    
    # 3. Send this list to the Flutter app!
    return heatmap_points

@app.post("/alerts/{alert_id}/location", response_model=schemas.LocationResponse)
def log_location(
    alert_id: int, 
    location: schemas.LocationCreate, 
    db: Session = Depends(get_db), 
    current_user: models.User = Depends(get_current_user)
):
    # 1. Verify the alert exists and belongs to this user
    alert = db.query(models.Alert).filter(
        models.Alert.id == alert_id, 
        models.Alert.user_id == current_user.id
    ).first()

    if not alert:
        raise HTTPException(status_code=404, detail="Active alert not found")

    # 2. Save the new GPS coordinates
    new_location = models.LocationLog(
        alert_id=alert_id,
        latitude=location.latitude,
        longitude=location.longitude
    )
    
    db.add(new_location)
    db.commit()
    db.refresh(new_location)
    
    print(f"📍 Location Update for Alert {alert_id}: {location.latitude}, {location.longitude}")
    return new_location

# --- AI AUDIO ANALYSIS ENGINE ---
def analyze_audio_for_distress(file_path: str, alert_id: int):
    print(f"🤖 AI Analyzer starting on: {file_path}...")
    try:
        # 1. Convert the web audio to raw WAV format for the AI
        audio = AudioSegment.from_file(file_path)
        wav_path = file_path.replace(".m4a", ".wav").replace(".webm", ".wav")
        audio.export(wav_path, format="wav")
        
        # 2. Load the WAV file into the Speech Recognizer
        recognizer = sr.Recognizer()
        with sr.AudioFile(wav_path) as source:
            audio_data = recognizer.record(source)
            
        # 3. Transcribe using Google's free AI speech-to-text
        transcription = recognizer.recognize_google(audio_data).lower()
        print(f"📝 AI Transcription: '{transcription}'")
        
        # 4. Check for distress keywords
        danger_words = ["help", "stop", "please", "leave me", "no", "police", "bachao"]
        
        if any(word in transcription for word in danger_words):
            print("\n" + "🚨"*10)
            print("CRITICAL: DISTRESS KEYWORDS DETECTED BY AI!")
            print("🚨"*10 + "\n")
            
            # --- TWILIO TRIGGER ---
            # We initialize Twilio and send a SECOND text message!
            client = Client(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN)
            message_body = f"⚠️ AI ALERT: Audio distress detected for Alert {alert_id}! Transcript: '{transcription}'"
            
            client.messages.create(
                body=message_body,
                from_=TWILIO_PHONE_NUMBER,
                to="+919876543210" # Replace with your VERIFIED emergency contact number!
            )
            print("✅ AI Escalation SMS Sent!")
            
        else:
            print("✅ AI Analysis: No distress keywords found in audio.")
            
    except sr.UnknownValueError:
        print("🤖 AI Analysis: Could not understand the audio (too much noise/silence).")
    except Exception as e:
        print(f"🤖 AI Analysis Error: {e}")

# --- AUDIO EVIDENCE RECEIVER ---
# Make sure the evidence folder exists when the server starts
os.makedirs("evidence", exist_ok=True)

@app.post("/alerts/{alert_id}/audio")
async def upload_audio_evidence(alert_id: int, file: UploadFile = File(...)):
    # Create a unique filename using the alert ID
    file_location = f"evidence/alert_{alert_id}_{file.filename}"
    
    # Save the incoming audio file to the hard drive
    with open(file_location, "wb+") as file_object:
        shutil.copyfileobj(file.file, file_object)
        
    print("\n" + "="*50)
    print(f"🎙️ SECURE EVIDENCE RECEIVED 🎙️")
    print(f"Alert ID: {alert_id}")
    print(f"File saved to: {file_location}")
    print("="*50 + "\n")
    # Pass the saved file to the AI in a background thread so it doesn't freeze the app!
    threading.Thread(target=analyze_audio_for_distress, args=(file_location, alert_id)).start()
    
    return {"status": "success", "file_path": file_location}
