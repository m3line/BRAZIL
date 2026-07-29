import pandas as pd

# 1. open main file
df_orders = pd.read_csv("C:/Users/melin/Downloads/BRAZILCOMM/olist_orders_dataset.csv")
df_customers = pd.read_csv("C:/Users/melin/Downloads/BRAZILCOMM/olist_customers_dataset.csv")


# 2. to understand the data structure  :

print("-- 10 first lines --")
print(df_orders.head(10)) 
#... colonnes

#______________________________________________________________________

print("\n-- Infos about colums and missing datas --")
print(df_orders.info())
# 4   order_approved_at              99281 non-null  str  
# 5   order_delivered_carrier_date   97658 non-null  str  
# 6   order_delivered_customer_date  96476 non-null  str 
# OUT OF : 99441 entries so theres something missing here 
#______________________________________________________________________

print("\n-- NUMBER OF MISSING DATAS PER COLUMN--")
print(df_orders.isnull().sum())
#______________________________________________________________________

print("\n-- Why are delivery dates missing ? --") #isolation then see their status and count them
missing_delivery = df_orders[df_orders['order_delivered_customer_date'].isnull()]
print(missing_delivery['order_status'].value_counts())

#______________________________________________________________________

print("\n-- LOGISTICS : Delivery Performance Analysis --")

#CONVERT : STR TO DTC
df_orders['order_delivered_customer_date'] = pd.to_datetime(df_orders['order_delivered_customer_date'])
df_orders['order_estimated_delivery_date'] = pd.to_datetime(df_orders['order_estimated_delivery_date'])

# new column "arrival_delay_days" =  (Livraison - Estimation), TYPE : DAYS
# arrival_delay_days > 0 = late
df_orders['arrival_delay_days'] = (
                                    df_orders['order_delivered_customer_date'] - df_orders['order_estimated_delivery_date']
                                  ).dt.days

# % of orders being late
late_orders = df_orders[df_orders['arrival_delay_days'] > 0]
late_delivery_rate = (len(late_orders) / len(df_orders.dropna(subset=['order_delivered_customer_date']))) * 100

print(f"Percentage of orders delivered LATE: { late_delivery_rate:.2f }%")
print(f"Worst delay recorded: { df_orders['arrival_delay_days'].max() } days"
    )
#___________________________________________________________________________

