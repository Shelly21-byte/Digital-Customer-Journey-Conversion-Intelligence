
import pandas as pd
import numpy as np
from pathlib import Path

# Reproducible synthetic data
rng = np.random.default_rng(456)

# Project folders
BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / "DATA"
DATA_DIR.mkdir(exist_ok=True)

# Product categories and price ranges
categories = {
    "Electronics": {
        "items": [
            "Smartphone", "Headphones", "Laptop",
            "Smartwatch", "Bluetooth Speaker",
            "Power Bank", "Keyboard", "Monitor",
            "Wireless Mouse", "Tablet"
        ],
        "price_range": (500, 80000)
    },

    "Fashion": {
        "items": [
            "T-Shirt", "Jeans", "Jacket",
            "Sneakers", "Shirt", "Dress",
            "Hoodie", "Handbag", "Kurta",
            "Casual Shoes"
        ],
        "price_range": (299, 5000)
    },

    "Home & Kitchen": {
        "items": [
            "Mixer Grinder", "Cookware Set",
            "Table Lamp", "Bedsheet",
            "Storage Box", "Electric Kettle",
            "Wall Clock", "Coffee Maker",
            "Dining Set", "Air Fryer"
        ],
        "price_range": (399, 15000)
    },

    "Beauty & Personal Care": {
        "items": [
            "Face Wash", "Moisturizer",
            "Shampoo", "Conditioner",
            "Sunscreen", "Body Lotion",
            "Hair Serum", "Perfume",
            "Face Mask", "Lip Balm"
        ],
        "price_range": (199, 4000)
    },

    "Sports & Fitness": {
        "items": [
            "Yoga Mat", "Dumbbell Set",
            "Running Shoes", "Gym Bag",
            "Fitness Band", "Water Bottle",
            "Resistance Bands", "Skipping Rope",
            "Exercise Ball", "Sports Jacket"
        ],
        "price_range": (499, 20000)
    }
}

products = []
product_id = 1

for category, details in categories.items():

    min_price, max_price = details["price_range"]

    for i in range(100):

        item_name = details["items"][i % len(details["items"])]

        # Generate a synthetic product variant
        variant_number = (i // len(details["items"])) + 1

        product_name = (
            f"{item_name} - Variant {variant_number:02d}"
        )

        # Generate a category-specific price
        price = round(
            float(rng.uniform(min_price, max_price)), 2
        )

        products.append({
            "product_id": product_id,
            "product_name": product_name,
            "category": category,
            "price_inr": price
        })

        product_id += 1

# Create DataFrame
products_df = pd.DataFrame(products)

# Validate dataset
assert len(products_df) == 500
assert products_df["product_id"].is_unique
assert products_df["product_name"].is_unique
assert products_df.notna().all().all()
assert (products_df["price_inr"] > 0).all()

# Save CSV
output_file = DATA_DIR / "products.csv"

products_df.to_csv(output_file, index=False)

print("Product dataset generated successfully!")
print("Total products:", len(products_df))
print("Unique categories:", products_df["category"].nunique())
print("File saved at:", output_file)

print("\nProducts by category:")
print(products_df["category"].value_counts())

print("\nFirst five products:")
print(products_df.head())
