# schemas.py
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime

class UserCreate(BaseModel):
    full_name: str
    phone_number: str
    password: str
    safe_pin: str

class UserResponse(BaseModel):
    id: int
    full_name: str
    phone_number: str
    
    class Config:
        from_attributes = True

class Token(BaseModel):
    access_token: str
    token_type: str

# --- CONTACTS ---
class ContactCreate(BaseModel):
    contact_name: str
    contact_phone: str

class ContactResponse(ContactCreate):
    id: int
    is_active: bool
    
    class Config:
        from_attributes = True  # This tells Pydantic to read the SQLAlchemy database model

# --- ALERTS (We will need these next!) ---
class AlertCreate(BaseModel):
    alert_type: str 
    latitude: Optional[float] = None  # <-- ADD THIS
    longitude: Optional[float] = None # <-- ADD THIS

class AlertResponse(BaseModel):
    id: int
    status: str
    created_at: datetime
    
    class Config:
        from_attributes = True

class AlertCancel(BaseModel):
    safe_pin: str

# In schemas.py
class LocationCreate(BaseModel):
    latitude: float
    longitude: float

class LocationResponse(LocationCreate):
    id: int
    alert_id: int
    timestamp: datetime

    class Config:
        from_attributes = True