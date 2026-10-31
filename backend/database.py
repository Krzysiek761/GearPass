import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# Symulacja bazy w prywatnej podsieci Azure (Private IP: 10.0.3.4)
# Brak hardcoded haseł - pobieranie z .env
SQLALCHEMY_DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://user:pass@10.0.3.4:5432/gearpass"
)

engine = create_engine(SQLALCHEMY_DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)