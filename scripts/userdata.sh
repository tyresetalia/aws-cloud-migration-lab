#!/bin/bash
set -e

# Update & install web stack and mysql client
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y apache2 php php-mysql mysql-client unzip curl

# Install AWS CLI v2 on the instance
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Create web app directory
mkdir -p /var/www/html/app
cat << 'EOF' > /var/www/html/app/index.php
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>AWS Cloud Migration Portal — Live Cutover</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f4f6f9; margin: 0; padding: 25px; color: #333; }
        .header { background: #232f3e; color: #ff9900; padding: 20px; border-radius: 8px; margin-bottom: 25px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
        .card { background: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.05); }
        .badge { display: inline-block; padding: 6px 12px; font-weight: bold; border-radius: 4px; font-size: 0.85em; }
        .badge-success { background-color: #28a745; color: white; }
        .badge-info { background-color: #17a2b8; color: white; }
        table { width: 100%; border-collapse: collapse; margin-top: 15px; }
        th, td { text-align: left; padding: 12px; border-bottom: 1px solid #ddd; }
        th { background-color: #f8f9fa; }
        .btn { background: #ff9900; color: #111; padding: 10px 18px; border: none; border-radius: 4px; cursor: pointer; font-weight: bold; text-decoration: none; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Cloud Migration Lab: Live Cutover Web Portal</h1>
        <p>Migrated from On-Premises to AWS (Amazon EC2 &bull; Amazon RDS MySQL &bull; Amazon S3)</p>
    </div>

    <div class="card">
        <h2>Infrastructure & Target Verification</h2>
        <p><strong>Environment:</strong> <span class="badge badge-success">AWS PRODUCTION CLOUD</span></p>
        <p><strong>Database Target:</strong> Amazon RDS (MySQL 8.4)</p>
        <p><strong>Storage Target:</strong> Amazon S3 (Decoupled Assets)</p>
    </div>

    <div class="card">
        <h2>Live Database Records (from Amazon RDS)</h2>
        <?php
        $db_host = "migration-mysql-db.cba62y4wg81m.eu-west-1.rds.amazonaws.com";
        $db_user = "admin";
        $db_pass = "Migration2026Secure!";
        $db_name = "onprem_store";

        $conn = @new mysqli($db_host, $db_user, $db_pass, $db_name);

        if ($conn->connect_error) {
            echo "<p style='color: #dc3545;'><strong>Database Connection Pending Cutover:</strong> " . htmlspecialchars($conn->connect_error) . "</p>";
            echo "<p><em>Note: Database schema and data will be imported during Cutover Phase.</em></p>";
        } else {
            echo "<p style='color: #28a745;'><strong>Connected successfully to Amazon RDS MySQL!</strong></p>";
            $res = $conn->query("SELECT * FROM customers ORDER BY id ASC");
            if ($res && $res->num_rows > 0) {
                echo "<h3>Customers Table (Migrated)</h3>";
                echo "<table><tr><th>ID</th><th>Name</th><th>Email</th><th>Company</th></tr>";
                while($row = $res->fetch_assoc()) {
                    echo "<tr><td>{$row['id']}</td><td>{$row['first_name']} {$row['last_name']}</td><td>{$row['email']}</td><td>{$row['company']}</td></tr>";
                }
                echo "</table>";
            } else {
                echo "<p>No customer records found yet. Ready for data import.</p>";
            }
            $conn->close();
        }
        ?>
    </div>
</body>
</html>
EOF

# Set proper permissions
chown -R www-data:www-data /var/www/html/app
systemctl restart apache2
