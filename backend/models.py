from sqlalchemy import Column, Integer, String, Boolean, Float, ForeignKey, DateTime
from sqlalchemy.orm import relationship
from datetime import datetime
from database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    full_name = Column(String)
    phone_number = Column(String, unique=True, index=True)
    hashed_password = Column(String)
    safe_pin = Column(String) # 4-digit pin to cancel SOS
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    contacts = relationship("Contact", back_populates="owner")
    alerts = relationship("Alert", back_populates="user")

class Contact(Base):
    __tablename__ = "contacts"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    contact_name = Column(String)
    contact_phone = Column(String)
    is_active = Column(Boolean, default=True)

    owner = relationship("User", back_populates="contacts")

class Alert(Base):
    __tablename__ = "alerts"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    alert_type = Column(String) # "SOS_BUTTON" or "TIMER"
    status = Column(String, default="ACTIVE") 
    timer_expires_at = Column(DateTime, nullable=True) # For the auto-alert
    latitude = Column(Float, nullable=True)  # <-- ADD THIS
    longitude = Column(Float, nullable=True) # <-- ADD THIS
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="alerts")
    locations = relationship("LocationLog", back_populates="alert")

class LocationLog(Base):
    __tablename__ = "location_logs"

    id = Column(Integer, primary_key=True, index=True)
    alert_id = Column(Integer, ForeignKey("alerts.id"))
    latitude = Column(Float)
    longitude = Column(Float)
    timestamp = Column(DateTime, default=datetime.utcnow)

    alert = relationship("Alert", back_populates="locations")