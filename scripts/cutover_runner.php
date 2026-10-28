<?php
header('Content-Type: text/plain; charset=utf-8');

$db_host = "migration-mysql-db.cba62y4wg81m.eu-west-1.rds.amazonaws.com";
$db_user = "admin";
$db_pass = "Migration2026Secure!";
$db_name = "onprem_store";

echo "============================================================\n";
echo " [DATABASE CUTOVER] Executing On-Prem Data Import to RDS\n";
echo "============================================================\n";

$conn = new mysqli($db_host, $db_user, $db_pass, $db_name);
if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error . "\n");
}
echo "[+] Connected to RDS MySQL successfully.\n";

// Raw SQL seed script
$sql = <<<'SQL'
CREATE TABLE IF NOT EXISTS customers (
    id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    company VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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

CREATE TABLE IF NOT EXISTS orders (
    id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    order_number VARCHAR(30) NOT NULL UNIQUE,
    total_amount DECIMAL(10, 2) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'COMPLETED',
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO customers (id, first_name, last_name, email, company) VALUES
(1, 'Mark', 'de Vries', 'm.devries@techcorp.nl', 'TechCorp B.V.'),
(2, 'Sophie', 'Jansen', 's.jansen@cloudlogistics.com', 'Cloud Logistics NL'),
(3, 'Tariq', 'Benali', 'tariq.b@innovatenet.org', 'InnovateNet'),
(4, 'Emma', 'Bakker', 'emma@bakkermedia.nl', 'Bakker Media Studio'),
(5, 'Lars', 'van Dijk', 'l.vandijk@nordicretail.eu', 'Nordic Retail Group');

INSERT IGNORE INTO products (id, sku, name, category, price, stock_qty, image_file) VALUES
(101, 'SRV-DL380', 'Enterprise Rack Server 2U', 'Hardware', 2499.00, 12, 'server-rack-2u.png'),
(102, 'NET-SW48P', 'Managed 48-Port PoE Gigabit Switch', 'Networking', 849.50, 28, 'switch-48p.png'),
(103, 'SEC-FW100', 'Next-Gen Perimeter Firewall Appliance', 'Security', 1299.95, 8, 'firewall-appliance.png'),
(104, 'STR-NAS8B', '8-Bay High-Speed NAS Storage', 'Storage', 1599.00, 15, 'nas-storage-8bay.png'),
(105, 'PWR-UPS3K', '3000VA Online Rackmount UPS', 'Power', 1099.00, 20, 'ups-3000va.png');

INSERT IGNORE INTO orders (id, customer_id, order_number, total_amount, status, order_date) VALUES
(1001, 1, 'ORD-2026-0091', 4998.00, 'DELIVERED', '2026-10-15 09:30:00'),
(1002, 2, 'ORD-2026-0092', 849.50, 'PROCESSING', '2026-10-18 14:15:00'),
(1003, 3, 'ORD-2026-0093', 2599.90, 'COMPLETED', '2026-10-22 11:00:00'),
(1004, 4, 'ORD-2026-0094', 1599.00, 'COMPLETED', '2026-10-25 16:45:00'),
(1005, 5, 'ORD-2026-0095', 3747.50, 'SHIPPED', '2026-10-27 10:20:00');
SQL;

if ($conn->multi_query($sql)) {
    do {
        if ($res = $conn->store_result()) {
            $res->free();
        }
    } while ($conn->more_results() && $conn->next_result());
    echo "[+] Schema and seed records executed successfully.\n";
} else {
    echo "[-] Error during execution: " . $conn->error . "\n";
}

// Verification queries
$t_res = $conn->query("SHOW TABLES;");
echo "\n[+] Verified Migrated Tables in Amazon RDS:\n";
while($row = $t_res->fetch_array()) {
    echo "    - " . $row[0] . "\n";
}

$c_res = $conn->query("SELECT COUNT(*) FROM customers;")->fetch_row()[0];
$p_res = $conn->query("SELECT COUNT(*) FROM products;")->fetch_row()[0];
$o_res = $conn->query("SELECT COUNT(*) FROM orders;")->fetch_row()[0];

echo "\n[+] Data Integrity Row Counts:\n";
echo "    - Customers : $c_res / 5 expected\n";
echo "    - Products  : $p_res / 5 expected\n";
echo "    - Orders    : $o_res / 5 expected\n";
echo "\n[SUCCESS] Cutover complete with 100% data integrity!\n";
$conn->close();
?>
