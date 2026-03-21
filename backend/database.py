from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

# 1. Database file location
SQLALCHEMY_DATABASE_URL = "sqlite:///./guardian_safety.db"

# 2. Create the engine
engine = create_engine(
    SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False}
)

# 3. Create the session factory
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# 4. The base class that models.py will use
Base = declarative_base()