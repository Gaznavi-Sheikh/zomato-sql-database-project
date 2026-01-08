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
