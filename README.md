# AWS Cloud Migration Lab — On-Premises naar AWS Cloud (Lift-and-Shift & Replatform)

End-to-end On-Premises naar AWS migratie: migreren van een multi-tier webapplicatie, database cutover naar Amazon RDS (MySQL), en static asset synchronisatie naar Amazon S3 met minimale downtime en gegarandeerde data-integriteit.

---

## Inhoudsopgave
- [Doel & Zakelijke Context](#doel--zakelijke-context)
- [Architectuur & Netwerkontwerp](#architectuur--netwerkontwerp)
- [Migratiestrategie (6 R's van AWS)](#migratiestrategie-6-rs-van-aws)
- [Componenten & Specificaties](#componenten--specificaties)
- [Projectstructuur](#projectstructuur)
- [Uitgevoerde Fasen & Bewijslast](#uitgevoerde-fasen--bewijslast)
- [Data Integrity & Audit Validatie](#data-integrity--audit-validatie)
- [Troubleshooting & Incident Response](#troubleshooting--incident-response)
- [FinOps & Resource Teardown](#finops--resource-teardown)

---

## Doel & Zakelijke Context

In dit lab treed ik op als **Cloud & Migration Engineer** en voer ik een volledige, end-to-end migratie uit van een lokale (on-premises gesimuleerde) 3-tier productie-omgeving naar **Amazon Web Services (AWS)**.

### Belangrijkste doelen:
1. **Rehost (Lift-and-Shift) van de compute-laag**: Web- en applicatieserver verhuizen naar een geharde AWS EC2-instance in een dedicated VPC met strikte Security Groups.
2. **Replatform van de database-laag**: Migreren van een lokale on-premise MySQL-server naar een volledig beheerde **Amazon RDS MySQL**-instance in een hermetisch afgesloten privé-subnet.
3. **Storage Ontkoppeling (Stateless architecture)**: Lokale uploadbestanden en statische media overzetten naar **Amazon S3** (`aws s3 sync`) met IAM Instance Profile authenticatie (geen gehardcodeerde AWS keys).
4. **Data-integriteit & Cutover**: Zero data loss cutover bewerkstelligen met transactieconsistente exports en geautomatiseerde row-count & hash validatie.
5. **Security & Least Privilege**: Toegangsbeveiliging inrichten via **Security Group Chaining** (RDS MySQL accepteert uitsluitend verkeer vanaf `app-sg`) en IAM Least Privilege.

---

## Architectuur & Netwerkontwerp

```
+----------------------------------------------------------------------------------------------------+
|                                    ON-PREMISES (BRON)                                              |
|  [ Web Server (Apache/PHP) ] ---> [ Lokale MySQL: onprem_store ] + [ Lokale Uploads: 5 assets ]    |
+-------------------------------------------------|--------------------------------------------------+
                                                  |
                                (Migratie: Cutover & S3 Sync)
                                                  |
                                                  v
+----------------------------------------------------------------------------------------------------+
|                                         AWS CLOUD (DOEL)                                           |
|                                                                                                    |
|  [ Dedicated VPC: migration-vpc (vpc-0272e76009456f31d - 10.0.0.0/16) ]                            |
|                                                                                                    |
|    [ Publiek Subnet: migration-public-subnet-1a (subnet-020aeb84308493f97 - 10.0.1.0/24) ]         |
|      - Internet Gateway: migration-igw (igw-0472d50f0b3d87230)                                     |
|      - Route Table: migration-public-rt (0.0.0.0/0 -> IGW)                                         |
|      - EC2 Web Server: migration-web-server (i-08202ae0f9793cfe2) [app-sg]                         |
|          |                                                                                         |
|          |-- (IAM Instance Profile: EC2-App-Migration-Profile) ---> [ Amazon S3: migration-assets ]|
|          |                                                                                         |
|          |-- (Port 3306 - Security Group Chaining: rds-sg allows ONLY app-sg)                      |
|          v                                                                                         |
|    [ DB Subnet Group: migration-db-subnet-group ]                                                  |
|      - Privé Subnet A: migration-private-db-subnet-1a (subnet-05546ac4f14e372c5 - 10.0.10.0/24)   |
|      - Privé Subnet B: migration-private-db-subnet-1b (subnet-0cdadc05a06a83608 - 10.0.11.0/24)   |
|      - Amazon RDS MySQL: migration-mysql-db (MySQL 8.4 - Non-Public)                               |
|                                                                                                    |
+----------------------------------------------------------------------------------------------------+
```

---

## Migratiestrategie (6 R's van AWS)

Binnen het **AWS Cloud Adoption Framework (CAF)** zijn voor deze transitie twee gerichte strategieën toegepast:
- **Rehost (Lift-and-Shift)**: De webapplicatielaag is gemigreerd naar EC2 met minimale codewijzigingen, waardoor de 'time-to-market' kort is en de transitie direct operationeel was.
- **Replatform (Lift-Tinker-and-Shift)**: De database is direct getransformeerd naar **Amazon RDS (MySQL)** om operationele overhead (handmatige back-ups, OS patching, storage provisioning) te elimineren.
- **Storage Decoupling**: Lokale bestandsopslag op de schijf van de webserver is ontkoppeld naar **Amazon S3**, waarmee de webserver stateless wordt en gereed is voor toekomstige Auto Scaling Groups.

---

## Componenten & Specificaties

| Component | AWS Resource Naam | Resource ID / Specificatie | Netwerk / Beveiliging |
| :--- | :--- | :--- | :--- |
| **Virtual Private Cloud** | `migration-vpc` | `vpc-0272e76009456f31d` | CIDR `10.0.0.0/16` in `eu-west-1` |
| **Publiek Subnet** | `migration-public-subnet-1a` | `subnet-020aeb84308493f97` | `10.0.1.0/24` (AZ: `eu-west-1a`) + Public IP on launch |
| **Privé DB Subnet A** | `migration-private-db-subnet-1a` | `subnet-05546ac4f14e372c5` | `10.0.10.0/24` (AZ: `eu-west-1a`) - Strikt privé |
| **Privé DB Subnet B** | `migration-private-db-subnet-1b` | `subnet-0cdadc05a06a83608` | `10.0.11.0/24` (AZ: `eu-west-1b`) - Multi-AZ Subnet Group |
| **Internet Gateway** | `migration-igw` | `igw-0472d50f0b3d87230` | Gekoppeld aan `migration-vpc` |
| **Route Table** | `migration-public-rt` | `rtb-071026fcef40ad329` | `0.0.0.0/0` gerouteerd naar `migration-igw` |
| **Security Group App** | `app-sg` | `sg-06580017c5f070a37` | Inbound: HTTP (80) & SSH (22) |
| **Security Group RDS** | `rds-sg` | `sg-0177fbc0a6302e74e` | Inbound: MySQL (3306) **ALLEEN** toegestaan vanaf `app-sg` |
| **Amazon RDS MySQL** | `migration-mysql-db` | `db.t3.micro` (MySQL 8.4) | `PubliclyAccessible: false`, DB: `onprem_store` |
| **Amazon EC2 Instance** | `migration-web-server` | `i-08202ae0f9793cfe2` | Ubuntu 24.04 LTS (`t3.micro`) |
| **Object Storage (S3)** | `migration-assets` | `s3://migration-assets-208643047372` | Privé bucket voor statische uploads |
| **IAM Instance Role** | `EC2-App-Migration-Role` | Instance Profile: `EC2-App-Migration-Profile` | Least Privilege S3 & SSM beheer |

---

## Projectstructuur

```
aws-cloud-migration-lab/
├── documentatie/
│   ├── pre_migration_baseline.json     # Pre-migration audit manifest (SHA256 & row-counts)
│   └── post_migration_audit_report.json # Post-cutover audit verificatierapport
├── screenshots/                        # Gevalideerde bewijslast van CLI en AWS Console
├── scripts/
│   ├── cutover_database.py             # Geautomatiseerd SSM cutover script
│   ├── cutover_runner.php              # Multi-query SQL import & cutover runner
│   ├── userdata.sh                     # EC2 Cloud-init bootstrap script (Apache, PHP, MySQL)
│   ├── verify_integrity.py             # Pre-migration data baseline checker
│   └── verify_post_migration.py        # Post-migration vergelijking en audit validator
├── source-environment/
│   ├── db/schema_and_data.sql          # Bron database schema en initiële transacties
│   └── uploads/                        # Lokale on-prem mediabestanden
└── README.md                           # Dit document
```

---

## Uitgevoerde Fasen & Bewijslast

### Fase 0: FinOps & Budgetbeheer
- **Doel**: Voorkomen van onverwachte cloudkosten tijdens migratiewerkzaamheden.
- **Uitvoering**: Verificatie van een actief **Zero-Spend Budget** ($1.00 drempel, status Healthy) met e-mailwaarschuwingen.
- **Bewijs**: [01-aws-budget-active.png](screenshots/01-aws-budget-active.png)

### Fase 1: Bronomgeving & Pre-Migration Baseline
- **Doel**: Opzetten van de on-premises simulatie en vastleggen van een cryptografische audit baseline vóór de cutover.
- **Uitvoering**: Database schema [`schema_and_data.sql`](source-environment/db/schema_and_data.sql) met 3 tabellen (`customers`, `products`, `orders`) en 5 lokale uploads. SHA-256 baseline audit gegenereerd via [`verify_integrity.py`](scripts/verify_integrity.py).

### Fase 2: Dedicated AWS Netwerkinfrastructuur (VPC & Subnets)
- **Doel**: Een geïsoleerde cloud-infrastructuur bouwen met strikte scheiding tussen publieke web-tier en afgeschermde database-tier.
- **Uitvoering via AWS CLI**:
  - Aanmaken van `migration-vpc` (`10.0.0.0/16`): [02-cli-create-vpc.png](screenshots/02-cli-create-vpc.png)
  - Publiek Subnet (`10.0.1.0/24` in `eu-west-1a`): [03-cli-subnet-public-1a.png](screenshots/03-cli-subnet-public-1a.png)
  - Privé DB Subnet 1 (`10.0.10.0/24` in `eu-west-1a`): [04-cli-subnet-private-db-1a.png](screenshots/04-cli-subnet-private-db-1a.png)
  - Privé DB Subnet 2 (`10.0.11.0/24` in `eu-west-1b`): [05-cli-subnet-private-db-1b.png](screenshots/05-cli-subnet-private-db-1b.png)
  - Internet Gateway aanmaken & koppelen: [06-cli-create-igw.png](screenshots/06-cli-create-igw.png)
  - Route Table en associatie: [07-cli-create-routetable.png](screenshots/07-cli-create-routetable.png) & [08-cli-associate-route-table.png](screenshots/08-cli-associate-route-table.png)
  - Visualisatie in AWS Console Resource Map: [18-console-vpc-resourcemap.png](screenshots/18-console-vpc-resourcemap.png)

### Fase 3: Security Group Chaining & Netwerkbeveiliging
- **Doel**: Toegangsbeveiliging inrichten volgens het **Zero Trust / Least Privilege** principe.
- **Uitvoering**:
  - Security Groups `app-sg` en `rds-sg` aangemaakt: [09-cli-create-security-groups.png](screenshots/09-cli-create-security-groups.png)
  - Web Server Ingress geconfigureerd (HTTP 80 & SSH 22): [10-cli-ingress-app-sg.png](screenshots/10-cli-ingress-app-sg.png)
  - **Security Group Chaining**: MySQL poort 3306 op `rds-sg` uitsluitend toegestaan vanuit `app-sg` (`ReferencedGroupInfo: sg-06580017c5f070a37`). Geen enkel extern IP kan de database benaderen: [11-cli-ingress-rds-sg-chaining.png](screenshots/11-cli-ingress-rds-sg-chaining.png)

### Fase 4: Amazon RDS MySQL Provisioning
- **Doel**: Uitrollen van een managed database in de private subnets.
- **Uitvoering**:
  - DB Subnet Group `migration-db-subnet-group` aangemaakt: [12-cli-create-db-subnet-group.png](screenshots/12-cli-create-db-subnet-group.png)
  - RDS MySQL 8.4 instance gelanceerd met `PubliclyAccessible: false`: [13-cli-create-rds-instance.png](screenshots/13-cli-create-rds-instance.png)
  - Status verificatie in AWS Console (Available): [19-console-rds-available.png](screenshots/19-console-rds-available.png)

### Fase 5: Static Asset Migratie naar Amazon S3
- **Doel**: Ontkoppelen van statische bestanden van de webserver voor een stateless architectuur.
- **Uitvoering**:
  - Dedicated S3 bucket `s3://migration-assets-208643047372` aangemaakt: [14-cli-create-s3-bucket.png](screenshots/14-cli-create-s3-bucket.png)
  - Synchronisatie van alle uploads uitgevoerd via `aws s3 sync`: [15-cli-s3-sync-assets.png](screenshots/15-cli-s3-sync-assets.png)

### Fase 6: IAM Instance Profile & Compute Rehost (EC2)
- **Doel**: Veilige rol-gebaseerde authenticatie zonder hardcoded credentials en uitrol van de web-tier.
- **Uitvoering**:
  - IAM Rol `EC2-App-Migration-Role` aangemaakt met EC2 trust policy: [16-cli-create-iam-role.png](screenshots/16-cli-create-iam-role.png)
  - S3 Access en SSM Managed policies gekoppeld en Instance Profile `EC2-App-Migration-Profile` gebouwd: [17-cli-create-instance-profile.png](screenshots/17-cli-create-instance-profile.png) & [21-cli-attach-ssm-policy.png](screenshots/21-cli-attach-ssm-policy.png)
  - EC2 Web Server (`t3.micro`) gelanceerd in het publieke subnet: [20-cli-launch-ec2.png](screenshots/20-cli-launch-ec2.png)

### Fase 7: Database Cutover & Live Productie Validatie
- **Doel**: Realtime omschakeling (cutover) van data en verificatie van de live webapplicatie.
- **Uitvoering**:
  - Web applicatie initieel online gebracht en verbinding met RDS gevalideerd (vóór cutover): [22-web-portal-connected-pre-cutover.png](screenshots/22-web-portal-connected-pre-cutover.png)
  - Cutover uitgevoerd: transactieconsistente import van tabellen en data in RDS MySQL via de webserver bridge.
  - **Live Productie Web Portal**: Volledig operationeel met live klantenrecords en S3 decoupled asset pointers: [23-web-portal-live-production-cutover.png](screenshots/23-web-portal-live-production-cutover.png)

---

## Data Integrity & Audit Validatie

Na de migratie is een geautomatiseerde audit uitgevoerd via [`verify_post_migration.py`](scripts/verify_post_migration.py) om te verifiëren dat er tijdens de cutover **geen data verloren is gegaan (Zero Data Loss)**:

```text
=================================================================
 [POST-MIGRATION AUDIT] Target AWS Production Verification
=================================================================
[+] Validating Database Tables & Row Counts:
    - Table 'customers ': Expected = 5, Actual = 5 -> [PASSED]
    - Table 'products  ': Expected = 5, Actual = 5 -> [PASSED]
    - Table 'orders    ': Expected = 5, Actual = 5 -> [PASSED]

[+] Validating S3 Decoupled Static Assets:
    - Assets Count     : Expected = 5, Actual = 5 -> [PASSED]

=================================================================
[OVERALL VERDICT] MIGRATION_SUCCESSFUL (Zero Data Loss)
[+] Audit Report saved to: documentatie/post_migration_audit_report.json
=================================================================
```

---

## Troubleshooting & Incident Response

Tijdens het migratieproces zijn reële cloud-incidenten en configuratie-uitdagingen methodisch gediagnosticeerd en opgelost (*Symptoom → Diagnose → Oorzaak → Oplossing*):

### Incident 1: RDS DB Subnet Group vereist minimale Multi-AZ dekking
- **Symptoom**: Bij het aanmaken van de DB Subnet Group trad een validatiefout op wanneer er slechts één subnet werd opgegeven.
- **Diagnose**: AWS RDS vereist om redenen van High Availability en failover-capaciteit dat een DB Subnet Group minimaal twee subnets in verschillende Availability Zones omvat.
- **Oorzaak**: In de initiële opzet was alleen `subnet-05546ac4f14e372c5` in `eu-west-1a` aangemaakt.
- **Oplossing**: Een tweede privé database-subnet `subnet-0cdadc05a06a83608` aangemaakt in `eu-west-1b`. Beide subnets zijn samengevoegd in `migration-db-subnet-group`, waarna de provisioning direct slaagde.

### Incident 2: RDS MySQL Hermetische Toegang & Chained Security Groups
- **Symptoom**: Lokale clients vanaf het on-premises netwerk kunnen het RDS MySQL endpoint niet rechtstreeks pingen of verbinden op poort 3306.
- **Diagnose**: Gewenst beveiligingsgedrag. De RDS database is geconfigureerd met `PubliclyAccessible: false` en heeft geen route naar de Internet Gateway.
- **Oorzaak**: Compliance en security vereisen dat de database niet blootstaat aan het publieke internet.
- **Oplossing**: Toegang is strikt geïmplementeerd via **Security Group Chaining**: alleen de `app-sg` van de webserver mag communiceren met `rds-sg`. De data-cutover is vervolgens uitgevoerd via de geautoriseerde EC2 bridge.

### Incident 3: EC2 Instance Connect Sleutellengte Validatie
- **Symptoom**: `aws ec2-instance-connect send-ssh-public-key` gaf een foutmelding: `Parameter validation failed: Invalid length for parameter SSHPublicKey, value: 77, valid min length: 80`.
- **Diagnose**: De geteste Ed25519 public key had een compactere payload dan de door de AWS EC2-IC API verwachte minimale lengte van 80 bytes.
- **Oorzaak**: AWS EC2 Instance Connect vereist standaard een RSA-sleutel van minimaal 2048-bits voor kortstondige authenticatie.
- **Oplossing**: Een standaard RSA 2048-bit sleutel gegenereerd en aangeleverd aan de API, waarna de tijdelijke SSH-sleutel binnen seconden succesvol werd geaccepteerd (`Success: true`).

### Incident 4: EC2 Instance Profile IAM Permissie Sync Latency
- **Symptoom**: Direct na het koppelen van de IAM Rol aan het Instance Profile gaf een instant API-aanroep aan dat de instantie nog niet direct als SSM managed target reageerde.
- **Diagnose**: IAM permissies en Instance Profile koppelingen hebben in AWS een lichte 'eventual consistency' propagatietijd (ongeveer 30–60 seconden).
- **Oorzaak**: De EC2 metadata service en SSM Agent peilen periodiek naar nieuw toegekende IAM credential tokens.
- **Oplossing**: Gecontroleerd gewacht tot de token refresh cyclus was voltooid en de communicatie succesvol tot stand was gebracht.

---

## FinOps & Resource Teardown

Conform professionele FinOps-principes zijn na het afronden en vastleggen van alle migratievalidaties alle actieve AWS-bronnen direct ontmanteld om cloudkosten te vermijden:

1. **Amazon RDS MySQL verwijderd**:
   ```powershell
   aws rds delete-db-instance --db-instance-identifier "migration-mysql-db" --skip-final-snapshot --delete-automated-backups
   ```
2. **Amazon EC2 Web Server beëindigd**:
   ```powershell
   aws ec2 terminate-instances --instance-ids "i-08202ae0f9793cfe2"
   ```
3. **Amazon S3 Bucket geleegd en verwijderd**:
   ```powershell
   aws s3 rb s3://migration-assets-208643047372 --force
   ```
4. **Vastlegging & Teardown Status**:
   - EC2: `terminated`
   - S3: `NoSuchBucket` (verwijderd)
   - RDS: `deleting` / afgebouwd
