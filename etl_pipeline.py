# Extract - Transform - Load

import os
import pandas as pd
from sqlalchemy import create_engine


# CONNECTION -> Structure : mysql+pymysql://utilisateur:mot_de_passe@serveur:port/base_de_données
engine = create_engine("mysql+pymysql://root:@127.0.0.1:3306/olist_ecommerce")

# CSV FILES NEEDED
data_to_import = {
    "olist_customers_dataset.csv": "olist_customers_dataset",
    "olist_orders_dataset.csv": "olist_orders_dataset",
    "olist_order_items_dataset.csv": "olist_order_items_dataset"
}

# path of the Kaggle's file
base_path = "C:/Users/melin/Downloads/BRAZILCOMM/"


# ETL Process for each items

for file_name, table_name in data_to_import.items():

    #construit le chemin du fichier.
    full_path = os.path.join(base_path, file_name)

    if os.path.exists(full_path):
        print(f" Ingesting and standardizing { file_name } :")
        
        # Extract
        df = pd.read_csv(full_path)

        # Transform
        # Standardisation columns : evrything in Lower Case 
        df.columns = df.columns.str.lower()
        
        print(f" Injecting {len(df)} rows into SQL table '{table_name}'...")
        
        # Load
        df.to_sql(
            name=table_name, 
            con=engine, 
            if_exists="replace", 
            index=False, 
            chunksize=10000
        )
        print(f" Table '{table_name}' successfully imported!\n")

    else:
        print(f" Error: File {file_name} not found at specified path.\n")

print(" ETL Pipeline complete. Data is ready in database!")
