-- ===============================================================
-- MySQL 8+ Script: Normalize Orders -> 1NF and OrderDetails -> 2NF
-- ===============================================================

-- -------------------------
-- CLEAN UP (if re-running)
-- -------------------------
DROP TABLE IF EXISTS OrdersRaw;
DROP TABLE IF EXISTS OrderItems;
DROP TABLE IF EXISTS OrderDetailsRaw;
DROP TABLE IF EXISTS Orders;
DROP TABLE IF EXISTS OrderDetails;

-- -------------------------
-- SETUP: Original OrdersRaw with comma-separated Products
-- -------------------------
CREATE TABLE OrdersRaw (
  OrderID INT,
  CustomerName VARCHAR(100),
  Products TEXT
);

INSERT INTO OrdersRaw (OrderID, CustomerName, Products) VALUES
(101, 'John Doe',    'Laptop, Mouse'),
(102, 'Jane Smith',  'Tablet, Keyboard, Mouse'),
(103, 'Emily Clark', 'Phone');

-- Verify raw data
SELECT * FROM OrdersRaw;


-- ===============================================================
-- QUESTION 1: Transform OrdersRaw to 1NF -> OrderItems (one product per row)
-- Uses a recursive CTE (MySQL 8+)
-- ===============================================================

CREATE TABLE OrderItems (
  OrderID INT,
  CustomerName VARCHAR(100),
  Product VARCHAR(200)
);

WITH RECURSIVE split AS (
  -- Anchor member: take the first product and remaining string
  SELECT
    OrderID,
    CustomerName,
    TRIM(SUBSTRING_INDEX(Products, ',', 1)) AS product,
    CASE
      WHEN INSTR(Products, ',') > 0 THEN TRIM(SUBSTRING(Products, INSTR(Products, ',') + 1))
      ELSE ''
    END AS rest
  FROM OrdersRaw
  UNION ALL
  -- Recursive member: repeat on the rest string until empty
  SELECT
    OrderID,
    CustomerName,
    TRIM(SUBSTRING_INDEX(rest, ',', 1)) AS product,
    CASE
      WHEN INSTR(rest, ',') > 0 THEN TRIM(SUBSTRING(rest, INSTR(rest, ',') + 1))
      ELSE ''
    END AS rest
  FROM split
  WHERE rest <> ''
)
INSERT INTO OrderItems (OrderID, CustomerName, Product)
SELECT OrderID, CustomerName, product
FROM split
ORDER BY OrderID, product;

-- Verify 1NF result
SELECT * FROM OrderItems ORDER BY OrderID, Product;


-- ===============================================================
-- QUESTION 2: Achieve 2NF for provided OrderDetailsRaw
-- Split CustomerName (dependent on OrderID) into Orders table
-- and keep OrderDetails with composite PK (OrderID, Product)
-- ===============================================================

-- Setup original OrderDetailsRaw (already in 1NF but has partial dependency)
CREATE TABLE OrderDetailsRaw (
  OrderID INT,
  CustomerName VARCHAR(100),
  Product VARCHAR(200),
  Quantity INT
);

INSERT INTO OrderDetailsRaw (OrderID, CustomerName, Product, Quantity) VALUES
(101, 'John Doe',    'Laptop', 2),
(101, 'John Doe',    'Mouse',  1),
(102, 'Jane Smith',  'Tablet', 3),
(102, 'Jane Smith',  'Keyboard',1),
(102, 'Jane Smith',  'Mouse',  2),
(103, 'Emily Clark', 'Phone',  1);

-- Verify raw orderdetails
SELECT * FROM OrderDetailsRaw ORDER BY OrderID;


-- Create normalized Orders and OrderDetails (2NF)
CREATE TABLE Orders (
  OrderID INT PRIMARY KEY,
  CustomerName VARCHAR(100)
);

CREATE TABLE OrderDetails (
  OrderID INT,
  Product VARCHAR(200),
  Quantity INT,
  PRIMARY KEY (OrderID, Product),
  FOREIGN KEY (OrderID) REFERENCES Orders(OrderID)
);

-- Populate Orders by selecting distinct OrderID -> removes partial dependency
INSERT INTO Orders (OrderID, CustomerName)
SELECT DISTINCT OrderID, CustomerName
FROM OrderDetailsRaw
ORDER BY OrderID;

-- Populate OrderDetails without CustomerName (now depends on full composite key)
INSERT INTO OrderDetails (OrderID, Product, Quantity)
SELECT OrderID, Product, Quantity
FROM OrderDetailsRaw
ORDER BY OrderID, Product;

-- Verify 2NF result
SELECT * FROM Orders ORDER BY OrderID;
SELECT * FROM OrderDetails ORDER BY OrderID, Product;


-- ===============================================================
-- Example JOIN to display full order lines (Orders + OrderDetails)
-- ===============================================================
SELECT o.OrderID, o.CustomerName, d.Product, d.Quantity
FROM Orders o
JOIN OrderDetails d ON o.OrderID = d.OrderID
ORDER BY o.OrderID, d.Product;

-- ===============================================================
-- End of script
-- ===============================================================
