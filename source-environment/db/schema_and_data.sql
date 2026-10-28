-- On-Premises E-Commerce & Customer Database Schema & Initial Seed Data
-- Database: onprem_store

CREATE DATABASE IF NOT EXISTS onprem_store;
USE onprem_store;

-- 1. Klanten tabel
CREATE TABLE IF NOT EXISTS customers (
    id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    company VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. Producten / Voorraad tabel
CREATE TABLE IF NOT EXISTS products (
    id INT AUTO_INCREMENT PRIMARY KEY,
    sku VARCHAR(20) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    stock_qty INT NOT NULL DEFAULT 0,
    image_file VARCHAR(100),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3. Bestellingen tabel (relatie)
CREATE TABLE IF NOT EXISTS orders (
    id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    order_number VARCHAR(30) NOT NULL UNIQUE,
    total_amount DECIMAL(10, 2) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'COMPLETED',
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Seed Data: Klanten
INSERT INTO customers (id, first_name, last_name, email, company) VALUES
(1, 'Mark', 'de Vries', 'm.devries@techcorp.nl', 'TechCorp B.V.'),
(2, 'Sophie', 'Jansen', 's.jansen@cloudlogistics.com', 'Cloud Logistics NL'),
(3, 'Tariq', 'Benali', 'tariq.b@innovatenet.org', 'InnovateNet'),
(4, 'Emma', 'Bakker', 'emma@bakkermedia.nl', 'Bakker Media Studio'),
(5, 'Lars', 'van Dijk', 'l.vandijk@nordicretail.eu', 'Nordic Retail Group');

-- Seed Data: Producten
INSERT INTO products (id, sku, name, category, price, stock_qty, image_file) VALUES
(101, 'SRV-DL380', 'Enterprise Rack Server 2U', 'Hardware', 2499.00, 12, 'server-rack-2u.png'),
(102, 'NET-SW48P', 'Managed 48-Port PoE Gigabit Switch', 'Networking', 849.50, 28, 'switch-48p.png'),
(103, 'SEC-FW100', 'Next-Gen Perimeter Firewall Appliance', 'Security', 1299.95, 8, 'firewall-appliance.png'),
(104, 'STR-NAS8B', '8-Bay High-Speed NAS Storage', 'Storage', 1599.00, 15, 'nas-storage-8bay.png'),
(105, 'PWR-UPS3K', '3000VA Online Rackmount UPS', 'Power', 1099.00, 20, 'ups-3000va.png');

-- Seed Data: Bestellingen
INSERT INTO orders (id, customer_id, order_number, total_amount, status, order_date) VALUES
(1001, 1, 'ORD-2026-0091', 4998.00, 'DELIVERED', '2026-10-15 09:30:00'),
(1002, 2, 'ORD-2026-0092', 849.50, 'PROCESSING', '2026-10-18 14:15:00'),
(1003, 3, 'ORD-2026-0093', 2599.90, 'COMPLETED', '2026-10-22 11:00:00'),
(1004, 4, 'ORD-2026-0094', 1599.00, 'COMPLETED', '2026-10-25 16:45:00'),
(1005, 5, 'ORD-2026-0095', 3747.50, 'SHIPPED', '2026-10-27 10:20:00');
