# 🧠 Deploying Resources *Conditionally* in Bicep — a Smart Way to Say “Only When Needed”

> **Bitesize Lesson 🍬**  
This one’s all about **making smart decisions in your code** — like only deploying stuff when you *actually* need it. It’s perfect for teammates trying to wrap their heads around the logic here… and yes, it’s also a handy breadcrumb trail for future-me 👋 in case I forget why things only deploy sometimes.

---

## 🎯 Why Conditional Deployment?

Imagine you’re managing environments at your **toy company** 🧸 — Dev, Test, and Production. You want full-on auditing and logging in **Prod**, but for Dev, maybe you just want to spin up the basics.

Rather than writing separate templates (ugh, maintenance nightmare), Bicep lets you **use conditions** to control what gets deployed, and when. 💡

---

## ⚙️ The Basics: Use `if` to Control Deployment

Let’s say you want to deploy a **storage account**, but only if a flag is set:

```bicep
param deployStorageAccount bool

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = if (deployStorageAccount) {
  name: 'teddybearstorage'
  location: resourceGroup().location
  kind: 'StorageV2'
}
```

🧠 If `deployStorageAccount` is `true`, boom — it gets created. If `false`, it’s skipped. Simple as that.

---

## 💬 Using Expressions as Conditions

Sometimes, instead of a straight-up `true/false`, you want to deploy something only if a **specific value is selected**, like `"Production"`:

```bicep
@allowed([
  'Development'
  'Production'
])
param environmentName string

resource auditingSettings 'Microsoft.Sql/servers/auditingSettings@2024-05-01-preview' = if (environmentName == 'Production') {
  parent: server
  name: 'default'
  properties: {}
}
```

💡 Pro Tip: Use a **variable** to keep it clean:

```bicep
var auditingEnabled = environmentName == 'Production'
```

Then reuse it like this:

```bicep
resource auditingSettings ... = if (auditingEnabled) {
  // ...
}
```

---

## 🔗 When One Resource Depends on Another Conditionally

Here’s where things get interesting: If you conditionally deploy a **storage account for auditing**, and your **auditing config** depends on it — you’ve gotta be careful.

```bicep
param environmentName string
param auditStorageAccountName string = 'bearaudit${uniqueString(resourceGroup().id)}'

var auditingEnabled = environmentName == 'Production'

resource auditStorageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = if (auditingEnabled) {
  name: auditStorageAccountName
  location: resourceGroup().location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
}
```

And then your SQL auditing resource might look like this:

```bicep
resource auditingSettings 'Microsoft.Sql/servers/auditingSettings@2024-05-01-preview' = if (auditingEnabled) {
  parent: server
  name: 'default'
  properties: {
    state: 'Enabled'
    storageEndpoint: auditingEnabled ? auditStorageAccount.properties.primaryEndpoints.blob : ''
    storageAccountAccessKey: auditingEnabled ? listKeys(auditStorageAccount.id, auditStorageAccount.apiVersion).keys[0].value : ''
  }
}
```

⚠️ **Why the weird `? : ''` stuff?**  
Even though the whole resource is conditionally deployed, Azure still **evaluates all expressions** inside it before checking the condition. So if you just reference the storage account directly and it *doesn’t exist*, 💥 you’ll get a `ResourceNotFound` error.

Using the ternary operator (`? :`) means you’re saying:  
> “If `auditingEnabled` is true, use the real value — otherwise, just pass an empty string.”

---

## ⛔ What *Not* to Do

Don’t try to create **two resources with the same name**, and use conditions to decide which one to deploy. Azure Resource Manager will treat that as a **name conflict**, and the deployment will fail.

If you find yourself doing this kind of thing a lot, take the hint:  
📦 **Use a module instead.**

---

## ✅ The Smart Way: Wrap It in a Module

Got a bunch of resources that should only deploy in one scenario (like Production)?  
Create a **module** for that group of resources, then deploy the whole module conditionally:

```bicep
module auditing 'modules/auditing.bicep' = if (auditingEnabled) {
  name: 'auditing-module'
  params: {
    location: location
    auditStorageAccountName: auditStorageAccountName
  }
}
```

Clean, modular, and way easier to manage.

---

## 🧪 Bonus Tip: Test Both Paths!

If you’re using conditions, make sure to test your template with:
- The condition set to `true`
- The condition set to `false`

This avoids surprises (like syntax or runtime errors) when something doesn’t get deployed.

---

## 🎯 TL;DR Recap

- ✅ Use `if (condition)` to deploy resources **only when needed**.
- 💡 Keep expressions clean by storing them in **variables**.
- 🤝 Watch out for **dependencies** on conditionally deployed resources — guard your expressions with `? : ''`.
- 🧱 Bundle related conditional logic into **modules** for clarity.
- 🧪 Always test both **true** and **false** scenarios.

---

Now you’ve got the power to deploy **only what you need, when you need it** — keeping your infrastructure lean, mean, and purpose-built. 🔧☁️

This one’s for you, future-me. Don’t forget to keep things DRY, clean, and conditional when it makes sense. 😉
