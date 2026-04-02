-- ============================================================
--  Electronic Marketplace System - CSS 2212 DBS Lab
--  Mini Project: SQL Schema & Queries
--  Team: Sristi Bose (240953660, Roll No. 56)
-- ============================================================
-- ========================
-- 1. DATABASE SETUP
-- ========================
CREATE DATABASE IF NOT EXISTS electromarket;
USE electromarket;
-- ========================
-- 2. TABLE DEFINITIONS (Normalized to 3NF)
-- ========================
-- Users table
CREATE TABLE IF NOT EXISTS users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    -- store bcrypt hash in production
    regno VARCHAR(20),
    phone VARCHAR(15),
    address TEXT,
    role ENUM('customer', 'admin') DEFAULT 'customer',
    joined_date DATE DEFAULT (CURRENT_DATE),
    CONSTRAINT chk_email CHECK (email LIKE '%@%.%')
);
-- Categories table
CREATE TABLE IF NOT EXISTS categories (
    cat_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(80) NOT NULL UNIQUE,
    icon VARCHAR(10)
);
-- Products table
CREATE TABLE IF NOT EXISTS products (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL CHECK (price > 0),
    stock INT DEFAULT 0 CHECK (stock >= 0),
    cat_id INT,
    rating DECIMAL(3, 1) DEFAULT 0.0,
    units_sold INT DEFAULT 0,
    emoji VARCHAR(10),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (cat_id) REFERENCES categories(cat_id) ON DELETE
    SET NULL,
        INDEX idx_product_price (price),
        INDEX idx_product_cat (cat_id),
        FULLTEXT INDEX ft_product_name (name, description)
);
-- Orders table
CREATE TABLE IF NOT EXISTS orders (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    order_date DATE DEFAULT (CURRENT_DATE),
    status ENUM('Processing', 'Shipped', 'Delivered', 'Cancelled') DEFAULT 'Processing',
    total_amt DECIMAL(10, 2),
    shipping VARCHAR(200),
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    INDEX idx_order_user (user_id),
    INDEX idx_order_date (order_date)
);
-- Order Items (bridge table between orders and products)
CREATE TABLE IF NOT EXISTS order_items (
    item_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    qty INT NOT NULL CHECK (qty > 0),
    price DECIMAL(10, 2) NOT NULL,
    -- price at time of purchase
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE,
    INDEX idx_oi_order (order_id),
    INDEX idx_oi_product (product_id)
);
-- Cart table
CREATE TABLE IF NOT EXISTS cart (
    cart_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    product_id INT NOT NULL,
    qty INT DEFAULT 1 CHECK (qty > 0),
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE,
    UNIQUE KEY uq_cart_user_product (user_id, product_id)
);
-- Reviews table
CREATE TABLE IF NOT EXISTS reviews (
    review_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    product_id INT NOT NULL,
    rating TINYINT CHECK (
        rating BETWEEN 1 AND 5
    ),
    comment TEXT,
    review_date DATE DEFAULT (CURRENT_DATE),
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE,
    UNIQUE KEY uq_review (user_id, product_id)
);
-- ========================
-- 3. SAMPLE DATA
-- ========================
INSERT INTO categories (name, icon)
VALUES ('Headphones', '🎧'),
    ('Tablets', '📱'),
    ('Accessories', '🔌'),
    ('Monitors', '🖥️'),
    ('Laptops', '💻'),
    ('Components', '💾'),
    ('Furniture', '🪑');
INSERT INTO users (name, email, password, regno, role)
VALUES (
        'Sristi Bose',
        'sristi@email.com',
        '$2b$12$hashedpassword1',
        '240953660',
        'customer'
    ),
    (
        'Raj Kumar',
        'raj@email.com',
        '$2b$12$hashedpassword2',
        '240953661',
        'customer'
    ),
    (
        'Priya Sharma',
        'priya@email.com',
        '$2b$12$hashedpassword3',
        '240953662',
        'customer'
    ),
    (
        'Admin User',
        'admin@electro.com',
        '$2b$12$hashedpassword4',
        NULL,
        'admin'
    );
INSERT INTO products (
        name,
        description,
        price,
        stock,
        cat_id,
        rating,
        units_sold,
        emoji
    )
VALUES (
        'Sony WH-1000XM5',
        'Industry-leading noise cancellation, 30hr battery',
        29999,
        45,
        1,
        4.8,
        230,
        '🎧'
    ),
    (
        'Apple iPad Air',
        'M1 chip, 10.9" Liquid Retina display, 5G capable',
        59999,
        12,
        2,
        4.9,
        180,
        '📱'
    ),
    (
        'Mechanical Keyboard',
        'TKL layout, Cherry MX switches, RGB backlight',
        6499,
        78,
        3,
        4.6,
        320,
        '⌨️'
    ),
    (
        'Samsung 27" Monitor',
        '4K UHD, IPS panel, 144Hz, HDR400',
        22999,
        34,
        4,
        4.7,
        95,
        '🖥️'
    ),
    (
        'Logitech MX Master 3',
        'Ergonomic wireless mouse, MagSpeed scroll',
        8499,
        67,
        3,
        4.8,
        410,
        '🖱️'
    ),
    (
        'Dell XPS 15 Laptop',
        'Intel i7, 16GB RAM, RTX 3050Ti, OLED display',
        149999,
        8,
        5,
        4.9,
        62,
        '💻'
    ),
    (
        'USB-C Hub 7-in-1',
        '4K HDMI, 3x USB-A, SD card, 100W PD',
        2199,
        120,
        3,
        4.5,
        560,
        '🔌'
    ),
    (
        'Bose QC 45',
        'WorldClass noise cancelling, 24hr battery',
        25999,
        30,
        1,
        4.7,
        145,
        '🎵'
    ),
    (
        'Gaming Chair Pro',
        'Ergonomic, 4D armrests, reclining 180°',
        14999,
        22,
        7,
        4.4,
        88,
        '🪑'
    ),
    (
        'Webcam 4K Ultra',
        '4K 30fps, auto-focus, built-in dual mic',
        7999,
        55,
        3,
        4.6,
        200,
        '📷'
    ),
    (
        'RTX 4070 GPU',
        'NVIDIA Ada, 12GB GDDR6X, DLSS 3',
        54999,
        5,
        6,
        4.9,
        40,
        '🎮'
    ),
    (
        'NVMe SSD 1TB',
        '7000MB/s read, M.2 2280, PCIe 4.0',
        7999,
        90,
        6,
        4.8,
        380,
        '💾'
    ),
    (
        'Smart LED Desk Lamp',
        '10 brightness levels, wireless charging base',
        1999,
        200,
        3,
        4.3,
        650,
        '💡'
    ),
    (
        'Razer DeathAdder V3',
        'Focus Pro 30K sensor, 90hr battery, 59g',
        5499,
        44,
        3,
        4.7,
        290,
        '🖱️'
    ),
    (
        'iPad Pro M2',
        'M2 chip, ProMotion 120Hz, Liquid Retina XDR',
        89999,
        7,
        2,
        4.9,
        55,
        '📲'
    ),
    (
        'External SSD 2TB',
        '1050MB/s, USB 3.2 Gen 2, compact rugged',
        9499,
        60,
        6,
        4.7,
        175,
        '🗂️'
    );
-- Demo orders
INSERT INTO orders (user_id, order_date, status, total_amt)
VALUES (1, '2024-11-20', 'Delivered', 34397),
    (1, '2024-10-15', 'Delivered', 8499),
    (2, '2024-11-25', 'Shipped', 22999),
    (3, '2024-12-01', 'Processing', 14498),
    (2, '2024-12-03', 'Delivered', 7999),
    (1, '2024-12-05', 'Processing', 7999);
INSERT INTO order_items (order_id, product_id, qty, price)
VALUES (1, 1, 1, 29999),
    -- Sony WH-1000XM5
    (1, 7, 2, 2199),
    -- USB-C Hub x2
    (2, 5, 1, 8499),
    -- Logitech MX Master
    (3, 4, 1, 22999),
    -- Monitor
    (4, 3, 1, 6499),
    -- Keyboard
    (4, 12, 1, 7999),
    -- SSD
    (5, 13, 1, 1999),
    -- Lamp
    (6, 10, 1, 7999);
-- Webcam
-- ========================
-- 4. VIEWS
-- ========================
-- Product catalogue view with category name
CREATE OR REPLACE VIEW v_product_catalogue AS
SELECT p.product_id,
    p.name,
    p.description,
    p.price,
    p.stock,
    c.name AS category,
    p.rating,
    p.units_sold,
    p.emoji
FROM products p
    LEFT JOIN categories c ON p.cat_id = c.cat_id;
-- User order history view
CREATE OR REPLACE VIEW v_order_history AS
SELECT o.order_id,
    u.name AS customer,
    u.email,
    o.order_date,
    o.status,
    COUNT(oi.item_id) AS item_count,
    SUM(oi.qty * oi.price) AS subtotal
FROM orders o
    JOIN users u ON o.user_id = u.user_id
    JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY o.order_id,
    u.name,
    u.email,
    o.order_date,
    o.status;
-- ========================
-- 5. STORED PROCEDURES
-- ========================
DELIMITER $$ -- Procedure: Place a full order from a user's cart
CREATE PROCEDURE PlaceOrder(IN p_user_id INT, IN p_shipping VARCHAR(200)) BEGIN
DECLARE v_order_id INT;
DECLARE v_total DECIMAL(10, 2);
-- Create order record
INSERT INTO orders (user_id, status, shipping)
VALUES (p_user_id, 'Processing', p_shipping);
SET v_order_id = LAST_INSERT_ID();
-- Copy cart items into order_items
INSERT INTO order_items (order_id, product_id, qty, price)
SELECT v_order_id,
    c.product_id,
    c.qty,
    p.price
FROM cart c
    JOIN products p ON c.product_id = p.product_id
WHERE c.user_id = p_user_id;
-- Update total on orders
SELECT SUM(qty * price) INTO v_total
FROM order_items
WHERE order_id = v_order_id;
UPDATE orders
SET total_amt = v_total * 1.18
WHERE order_id = v_order_id;
-- Clear user's cart
DELETE FROM cart
WHERE user_id = p_user_id;
SELECT v_order_id AS new_order_id,
    v_total AS subtotal;
END $$ -- Procedure: Get recommendations for a user
CREATE PROCEDURE GetRecommendations(IN p_user_id INT, IN p_limit INT) BEGIN -- Products in the same categories as previously purchased, ordered by popularity
SELECT p.product_id,
    p.name,
    p.price,
    p.emoji,
    c.name AS category,
    p.rating,
    p.units_sold,
    COUNT(oi2.product_id) AS purchase_freq
FROM products p
    JOIN categories c ON p.cat_id = c.cat_id
    JOIN order_items oi2 ON p.product_id = oi2.product_id
WHERE p.cat_id IN (
        -- Categories the user has bought from
        SELECT DISTINCT prod.cat_id
        FROM orders o
            JOIN order_items oi ON o.order_id = oi.order_id
            JOIN products prod ON oi.product_id = prod.product_id
        WHERE o.user_id = p_user_id
    )
    AND p.product_id NOT IN (
        -- Exclude already purchased products
        SELECT oi3.product_id
        FROM orders o3
            JOIN order_items oi3 ON o3.order_id = oi3.order_id
        WHERE o3.user_id = p_user_id
    )
    AND p.stock > 0
GROUP BY p.product_id,
    p.name,
    p.price,
    p.emoji,
    c.name,
    p.rating,
    p.units_sold
ORDER BY purchase_freq DESC,
    p.rating DESC
LIMIT p_limit;
END $$ -- Procedure: Update product rating from reviews
CREATE PROCEDURE UpdateProductRating(IN p_product_id INT) BEGIN
UPDATE products
SET rating = (
        SELECT ROUND(AVG(rating), 1)
        FROM reviews
        WHERE product_id = p_product_id
    )
WHERE product_id = p_product_id;
END $$ DELIMITER;
-- ========================
-- 6. TRIGGERS
-- ========================
DELIMITER $$ -- Trigger: Reduce stock after order item inserted
CREATE TRIGGER trg_reduce_stock
AFTER
INSERT ON order_items FOR EACH ROW BEGIN
UPDATE products
SET stock = stock - NEW.qty,
    units_sold = units_sold + NEW.qty
WHERE product_id = NEW.product_id;
END $$ -- Trigger: Restore stock if order is cancelled
CREATE TRIGGER trg_restore_stock
AFTER
UPDATE ON orders FOR EACH ROW BEGIN IF NEW.status = 'Cancelled'
    AND OLD.status != 'Cancelled' THEN
UPDATE products p
    JOIN order_items oi ON p.product_id = oi.product_id
SET p.stock = p.stock + oi.qty,
    p.units_sold = p.units_sold - oi.qty
WHERE oi.order_id = NEW.order_id;
END IF;
END $$ -- Trigger: Update rating after review insert/update
CREATE TRIGGER trg_update_rating_insert
AFTER
INSERT ON reviews FOR EACH ROW BEGIN
UPDATE products
SET rating = (
        SELECT ROUND(AVG(rating), 1)
        FROM reviews
        WHERE product_id = NEW.product_id
    )
WHERE product_id = NEW.product_id;
END $$ DELIMITER;
-- ========================
-- 7. INDEXES (Query Optimization)
-- ========================
-- Composite index for fast order-item lookups per user
CREATE INDEX idx_order_user_date ON orders(user_id, order_date DESC);
-- Index to speed up recommendation subquery (category lookup)
CREATE INDEX idx_product_cat_stock ON products(cat_id, stock);
-- Covering index for price-range filtering
CREATE INDEX idx_price_rating ON products(price, rating);
-- ========================
-- 8. COMPLEX QUERIES (Demo)
-- ========================
-- Q1: Revenue by category
SELECT c.name AS category,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(oi.qty) AS units_sold,
    SUM(oi.qty * oi.price) AS gross_revenue,
    ROUND(AVG(p.rating), 2) AS avg_rating
FROM categories c
    JOIN products p ON c.cat_id = p.cat_id
    JOIN order_items oi ON p.product_id = oi.product_id
    JOIN orders o ON oi.order_id = o.order_id
WHERE o.status != 'Cancelled'
GROUP BY c.name
ORDER BY gross_revenue DESC;
-- Q2: Top customers by spend
SELECT u.user_id,
    u.name,
    u.email,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(o.total_amt) AS total_spend,
    MAX(o.order_date) AS last_order
FROM users u
    JOIN orders o ON u.user_id = o.user_id
WHERE o.status != 'Cancelled'
GROUP BY u.user_id,
    u.name,
    u.email
ORDER BY total_spend DESC;
-- Q3: Frequently bought together (Market Basket)
SELECT a.product_id AS product_a,
    pa.name AS name_a,
    b.product_id AS product_b,
    pb.name AS name_b,
    COUNT(*) AS co_purchases
FROM order_items a
    JOIN order_items b ON a.order_id = b.order_id
    AND a.product_id < b.product_id
    JOIN products pa ON a.product_id = pa.product_id
    JOIN products pb ON b.product_id = pb.product_id
GROUP BY a.product_id,
    b.product_id,
    pa.name,
    pb.name
HAVING co_purchases > 0
ORDER BY co_purchases DESC
LIMIT 10;
-- Q4: Low stock alert (< 10 units)
SELECT p.product_id,
    p.name,
    c.name AS category,
    p.stock AS remaining_stock,
    p.price
FROM products p
    JOIN categories c ON p.cat_id = c.cat_id
WHERE p.stock < 10
ORDER BY p.stock ASC;
-- Q5: Monthly revenue trend
SELECT DATE_FORMAT(o.order_date, '%Y-%m') AS month,
    COUNT(DISTINCT o.order_id) AS orders,
    SUM(o.total_amt) AS revenue
FROM orders o
WHERE o.status != 'Cancelled'
GROUP BY month
ORDER BY month;
-- Q6: Recommendation query (standalone, for user_id = 1)
SELECT p.product_id,
    p.name,
    p.price,
    c.name AS category,
    p.rating,
    p.units_sold
FROM products p
    JOIN categories c ON p.cat_id = c.cat_id
WHERE p.cat_id IN (
        SELECT DISTINCT pr.cat_id
        FROM orders o
            JOIN order_items oi ON o.order_id = oi.order_id
            JOIN products pr ON oi.product_id = pr.product_id
        WHERE o.user_id = 1
    )
    AND p.product_id NOT IN (
        SELECT oi2.product_id
        FROM orders o2
            JOIN order_items oi2 ON o2.order_id = oi2.order_id
        WHERE o2.user_id = 1
    )
    AND p.stock > 0
ORDER BY p.units_sold DESC,
    p.rating DESC
LIMIT 5;