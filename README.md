# Zomato Database Management System (SQL Project)

## 📌 Project Overview
This project is a relational database design inspired by the Zomato food delivery system.
It demonstrates SQL concepts such as table design, primary keys, foreign keys,
constraints, and relationships between entities like customers, restaurants, orders, and payments.

## 🎯 Objectives
- Design a real-world food delivery database
- Implement relational constraints
- Maintain data integrity
- Practice SQL for interviews and real projects

## 🗄️ Database Schema
The database contains the following tables:
- RESTAURANT
- CATEGORY
- RESTAURANT_CATEGORY
- MENU
- MENU_ITEM
- CUSTOMER
- ADDRESS
- DELIVERY_PERSON
- ORDERS
- ORDER_ITEM
- PAYMENT
- REVIEW

## 🔗 Relationships
- CUSTOMER → ORDERS (1-to-Many)
- RESTAURANT → ORDERS (1-to-Many)
- MENU → MENU_ITEM (1-to-Many)
- ORDERS → ORDER_ITEM (1-to-Many)
- ORDERS → PAYMENT (1-to-1)
- CUSTOMER → REVIEW (1-to-Many)
- RESTAURANT → REVIEW (1-to-Many)

## 🛠️ Technologies Used
- Oracle SQL
- SQL*Plus

## 📂 Project Structure
```
zomato-sql-database-project/
├── ER-diagram/
│ ├── ER_Diagram_Database.png # ER diagram image
│ └── ER_Diagram_Database.pdf # ER diagram PDF
├── Insert_Data/
│ └── Data_Insertion_Queries.pdf # SQL queries to insert data into all tables
├── Report/
│ └── Zomato_SQL_Database_Project_Report.docx # Full project report
├── Schema/
│ └── Table_Creation_Queries.pdf # SQL queries to create all tables
└── README.md # Project description
```

## Database Tables
The database contains the following main tables:
- **CUSTOMER** – stores customer information  
- **ADDRESS** – stores customer addresses  
- **RESTAURANT** – stores restaurant information  
- **CATEGORY** – stores restaurant categories  
- **MENU** – stores menu information for restaurants  
- **MENU_ITEM** – stores individual menu items  
- **ORDERS** – stores order details  
- **ORDER_ITEM** – stores order item details  
- **PAYMENT** – stores payment information  
- **DELIVERY_PERSON** – stores delivery personnel info  
- **REVIEW** – stores customer reviews  

## Sample SQL Queries
- Retrieve all orders for a specific customer  
- Calculate total sales per restaurant  
- List menu items available for a restaurant  
- Fetch customer reviews for a restaurant  
- Track delivery status of orders  

The project now also includes a full advanced SQL query layer under
`database/queries/` (basic filtering/joins, plus advanced business
analytics), covering multi-table joins, subqueries and correlated
subqueries, `EXISTS`/`NOT EXISTS`, CTEs, conditional aggregation, date/time
analysis, window functions (`RANK`, `DENSE_RANK`, `ROW_NUMBER`, `LAG`/`LEAD`),
running totals, top-N-per-group ranking, and historical order-price
analysis. See `docs/query-analysis.md` for the query-performance notes
behind them.

## Future Enhancements
- Add stored procedures to automate repetitive tasks  
- Implement triggers for automated actions and data integrity  
- Integrate the database with backend applications  
- Introduce role-based access control for security  
- Optimize queries with indexing and performance improvements  
- Add support for coupons and loyalty programs  

## ▶️ How to Run the Project

Follow these steps to set up and run the Zomato SQL Database Project:

* **Open Your SQL Environment**  
  Use Oracle SQL Developer, MySQL Workbench, or any compatible SQL environment to execute the scripts.

* **Create the Database Tables**  
  - Open the SQL script: `Table_Creation_Queries.pdf`.
  - Execute all queries to create the tables in the correct order.  
  - Ensure that primary keys, foreign keys, and constraints are created successfully.

* **Insert Sample Data**  
  - Open the SQL script: `Data_Insertion_Queries.pdf`.  
  - Execute all queries to populate the tables with sample data.  
  - This will create 10 sample records for each table while maintaining all relationships.

* **Verify the Data**  
  - Use `SELECT * FROM <table_name>;` to check that tables are populated correctly.  
  - Check relationships between tables to ensure referential integrity is maintained.

* **View ER Diagram and Reports (Optional)**  
  - Open `ER-diagram/ER_Diagram_Databse.png` or `ER_Diagram_Databse.pdf` to see the database design.  
  - Open `report/Zomato_SQL_Database_Project_Report.pdf` for detailed documentation of tables, queries, and project explanation.



## 📌 Author
**Gaznavi Sheikh**
