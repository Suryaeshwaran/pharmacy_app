# PharmacyApp User Guide

1. [Introduction](#1-introduction)
2. [System Requirements](#2-system-requirements)
3. [Installation](#3-installation)
4. [Getting Started](#4-getting-started)  
   4.1 [Store Settings](#41-store-settings)  
   4.2 [Inventory Management](#42-inventory-management)  
   4.3 [Patient Management](#43-patient-management)  
   4.4 [Billing](#44-billing)  
   4.5 Agency Management
5. Reports
6. Maintenance
7. Frequently Asked Questions
8. Quick Reference

## 1. Introduction

### About PharmacyApp

PharmacyApp is a desktop application built specifically for pharmacy operations, designed to simplify daily tasks like billing, inventory tracking, and patient management. It runs on  Windows, storing all data securely on your local computer — no internet connection required for day-to-day use.

### Who This Guide Is For

This guide is written for pharmacy staff and owners who will use PharmacyApp daily — no technical background required. Each chapter covers one part of the app, with step-by-step instructions and screenshots where helpful.

### What PharmacyApp Can Do

- **Billing** — Create bills quickly, generate PDF receipts, and share them directly via WhatsApp
- **Inventory Management** — Track stock levels, monitor expiry dates, and get alerts for low stock
- **Patient Management** — Maintain patient records and manage a visit queue
- **Agency Purchases** — Record purchases from supplying agencies and track payments
- **Reports** — View daily, monthly, and yearly business summaries
- **Maintenance** — PharmacyInfo Setting, Backup & restore, Data cleanup

### How This Guide Is Organized

Each chapter builds on the previous one. If you're setting up PharmacyApp for the first time, we recommend reading Chapters 2–5 in order before jumping to specific feature chapters. Experienced users can jump directly to the relevant chapter or use the Quick Reference for a fast lookup.

## 2. System Requirements

### Supported Operating Systems

PharmacyApp supports **Windows OS** (Windows 8 and above). 

| Requirement       | Minimum                     |
|--------------------|------------------------------|
| Operating System   | Windows 8 or later           |
| Architecture       | 32-bit or 64-bit             |
| RAM                | 2 GB                         |
| Disk Space         | General free space required for app and database growth |
| Display            | Standard desktop resolution  |

### Prerequisites — Windows Deployment

PharmacyApp requires the **Microsoft Visual C++ Redistributable Runtime** to be installed on the system.

If PharmacyApp fails to launch or shows a missing DLL error, this runtime is likely not installed (or is corrupted). To fix it:

1. Download the **All-in-One Visual C++ Redistributable package** from TechPowerUp
   - Search: *techpowerup visual c++ redistributable runtimes all-in-one*
2. Extract the downloaded zip
3. Run `install_all.bat` as **Administrator**
4. Restart the machine

This package installs all VC++ runtime versions (2005 through 2022) in sequence, and resolves cases where individual installers fail due to corrupted or partially installed prior versions.

> **Note:** This step only needs to be done once per computer, before installing PharmacyApp for the first time.

## 3. Installation

### Step 1: Locate the Installer File

You will receive a compressed file such as:

> PharmacyApp-v0.9.0.zip

*(The version number may vary depending on release.)*

### Step 2: Extract the Files

1. Open the downloaded `.zip` file — this usually opens automatically with **WinZip** or your default extraction tool.
2. Create a new folder on your computer to hold the application files — for example, **PharmacyApp** or **PharmaApp**.
3. Click **Extract To**, then select the folder you just created.
4. Wait for all files to be extracted into that folder.

### Step 3: Run PharmacyApp

1. Open the folder where you extracted the files.
2. Double-click **`pharmacy_app.exe`**.
3. The application will launch and you're ready to start using PharmacyApp.

### Step 4: (Optional) Create a Desktop Shortcut

For quicker access:

1. Right-click on **`pharmacy_app.exe`**.
2. Select **Send to → Desktop (create shortcut)**.
3. Use this shortcut going forward to open PharmacyApp directly from your desktop.

> **Tip:** Keep the extracted folder intact — do not move or rename individual files inside it, as PharmacyApp relies on files staying together in the same location.

## 4. Getting Started

### 4.1 Store Settings

Before creating your first bill, set up your pharmacy's details. These details appear automatically on every bill, PDF receipt, and WhatsApp share.

**Steps:**

1. Open PharmacyApp and go to the **Maintenance**.
2. Select **Settings** tab.

   
   ![Settings tab](images/settings-tab.png)

3. Enter your pharmacy details:

   | Field | Description |
   |-------|--------------|
   | Name | Your pharmacy's name |
   | Address | Street address |
   | City | City / town |
   | Phone | Contact phone number |
   | GSTN | GST registration number |
   | REGN | Pharmacy registration number |

4. Click **Save**.

> **Note:** Any field left blank will simply not appear on your bills — you don't need to fill in every field for the app to work correctly.

Once saved, these details will automatically appear on the header of every bill you generate — whether printed, saved as PDF, or shared via WhatsApp.

### 4.2 Inventory Management

The Inventory module is where you manage all medicines in stock — adding new medicines, adjusting quantities, and editing details.

#### Adding a Medicine

1. Go to the **Inventory** tab.
2. Click **+ Add Medicine** at the bottom right.
3. Fill in the required details:

   - Medicine Name
   - Stock Quantity
   - Low Stock Alert
   - Price/unit
   - Batch Number
   - Expiry Date


4. Click **Add Medicine** to save.

   ![Add Medicine](images/add-medicine.png)

#### Managing Existing Medicines

Once added, medicines appear under the **All** tab. From here you can:

- **Adjust stock** — Click the **+** icon to add stock quantity.
- **Edit details** — Click the edit icon to update medicine information.

![Added Medicine](images/added-medicine.png)

#### Deleting a Medicine

The delete option is only enabled once a medicine's stock reaches **0**. Medicines with remaining stock cannot be deleted — this prevents accidental loss of stock and billing records that are still tied to that medicine.

### 4.3 Patient Management

The Patient Management screen lets you maintain a record of patients, search for existing patients quickly during billing, and add patients to the "Visiting Today" list so they appear directly in the billing screen.

![Patient Screen](images/patient-screen.png)

**Adding a New Patient**

1. Open the **Patients** screen from the main menu.
2. Click **Add Patient**.
3. Enter the required details:
   - Patient ID
   - Name
   - Phone Number
4. Click **Save** to add the patient to your records.

**Searching for a Patient**

1. Use the search bar at the top of the Patients screen.
2. Search by **Patient ID**, **Name**, or **Phone Number**.
3. Matching records will appear in the list below.

**Adding to Visiting Today List**

1. Search for the patient as described above.
2. Select the patient record from the search results.
3. Click **Add to Visiting Today**.
4. The patient will now appear in the Visiting Today list, and will be available for selection directly on the Billing screen.

*[On Search results Click "Visiting Today" to add to list]*

![Search Patient](images/search-patient.png)

**Editing or Deleting a Patient Record**

1. Search for the patient you want to update.
2. Select the record from the search results.
3. Click **Edit** to update details, or **Delete** to remove the patient record.
4. Confirm the action when prompted.

> **Note:** Patients added to the Visiting Today list will show up automatically on the Billing screen, making it faster to select them during checkout without searching again.

### 4.4 Billing

The Billing screen is where you generate bills for patients, whether they're visiting today or walking in. It allows you to search medicines, record patient details, capture payments, and generate a shareable bill.


![Billing Screen](images/billing-screen.png)

**Adding Medicines to the Bill**

1. Use the **Search Medicine** field to find the medicine by name.
2. Select the medicine from the search results.
3. Specify the required **quantity**.
4. Repeat to add multiple medicines to the same bill.

**Adding Patient Details**

You can add patient details in one of two ways:

- **From Visiting Today list:** Select a patient already added to the Visiting Today list (see [Patient Management](#43-patient-management)).
- **Manual entry:** Enter the patient's **Name** and **Phone Number** directly.

> **Note:** Adding a phone number allows you to share the bill via WhatsApp. If patient details are left blank, the bill will be saved as a **Walk-in** sale.

**Selecting Pharmacy Payment Method**

1. Choose the **Pharmacy Payment Method** for the medicine bill amount (e.g., Cash, UPI).

**Adding Fee Payment (if applicable)**

1. Enter the **Fee Amount**, if a consultation or service fee applies.
2. Select the **Fee Payment Method**.

**Generating the Bill**

1. Once medicines, patient details, and payment methods are entered, click **Generate Bill**.
2. This opens a **Bill Preview**.
3. From the preview, you can:
   - **Save and open as PDF**
   - **Share via WhatsApp**

![Bill Preview](images/bill-preview.png)

> **Note:** To edit or delete a bill after it has been generated, go to the **Reports** screen. See [Reports](#reports) for details.