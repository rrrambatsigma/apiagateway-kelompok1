from sqlalchemy.orm import Session

from .models import Item, User


def seed(db: Session) -> None:
    """Isi data dummy hanya jika tabel masih kosong (anti dobel-seed)."""
    if db.query(User).count() > 0:
        return

    users = [
        User(name="Ahmad Fauzi", email="ahmad@example.com", password="admin123", role="admin"),
        User(name="Budi Santoso", email="budi@example.com", password="user123", role="user"),
        User(name="Citra Ayu", email="citra@example.com", password="user123", role="user"),
        User(name="Dewi Lestari", email="dewi@example.com", password="user123", role="user"),
        User(name="Eko Prasetyo", email="eko@example.com", password="user123", role="user"),
        User(name="Fitri Handayani", email="fitri@example.com", password="user123", role="user"),
        User(name="Hendra Wijaya", email="hendra@example.com", password="user123", role="user"),
        User(name="Intan Nuraini", email="intan@example.com", password="user123", role="user"),
    ]

    items = [
        Item(name="Laptop Asus ROG", price=15000000, stock=10),
        Item(name="Keyboard Mechanical", price=750000, stock=25),
        Item(name="Mouse Wireless", price=250000, stock=40),
        Item(name="Monitor 27 inch", price=3200000, stock=12),
        Item(name="Headphone Studio", price=1800000, stock=18),
        Item(name="Webcam 1080p", price=450000, stock=30),
        Item(name="Speaker Bluetooth", price=600000, stock=22),
        Item(name="SSD NVMe 1TB", price=1400000, stock=50),
        Item(name="RAM 16GB DDR4", price=900000, stock=35),
        Item(name="Microphone USB", price=850000, stock=15),
    ]

    db.add_all(users)
    db.add_all(items)
    db.commit()