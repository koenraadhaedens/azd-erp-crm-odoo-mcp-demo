"""Create a deterministic, connected Contoso business scenario in an Odoo shell."""

from datetime import timedelta

from odoo import Command, fields


PREFIX = "DEMO-"


def upsert(model_name, domain, values):
    record = env[model_name].search(domain, limit=1)
    if record:
        record.write(values)
        return record
    return env[model_name].create(values)


def optional(label, operation):
    try:
        with env.cr.savepoint():
            operation()
    except Exception as exc:
        print(f"Realistic demo: skipped {label}: {exc}")


def seed_partners():
    country = env.ref("base.us")
    customers = {}
    customer_data = [
        ("Azure Peak Bikes", "Denver", "CO", "procurement@azurepeak.example", "+1 303 555 0101"),
        ("Northwind Health", "Seattle", "WA", "purchasing@northwindhealth.example", "+1 206 555 0102"),
        ("Fabrikam Hotels", "Chicago", "IL", "operations@fabrikamhotels.example", "+1 312 555 0103"),
        ("Adventure Works Retail", "Austin", "TX", "orders@adventureworks.example", "+1 512 555 0104"),
        ("Litware Education", "Boston", "MA", "facilities@litwareedu.example", "+1 617 555 0105"),
        ("Woodgrove Bank", "New York", "NY", "sourcing@woodgrovebank.example", "+1 212 555 0106"),
        ("Tailspin Toys", "Portland", "OR", "supply@tailspintoys.example", "+1 503 555 0107"),
        ("Consolidated Messenger", "Atlanta", "GA", "office@consolidated.example", "+1 404 555 0108"),
    ]
    for index, (name, city, state_code, email, phone) in enumerate(customer_data, 1):
        state = env["res.country.state"].search(
            [("country_id", "=", country.id), ("code", "=", state_code)], limit=1
        )
        partner = upsert(
            "res.partner",
            [("ref", "=", f"{PREFIX}CUST-{index:03d}")],
            {
                "name": name,
                "ref": f"{PREFIX}CUST-{index:03d}",
                "is_company": True,
                "company_type": "company",
                "customer_rank": 1,
                "street": f"{100 + index} Market Street",
                "city": city,
                "state_id": state.id,
                "zip": f"{80000 + index}",
                "country_id": country.id,
                "email": email,
                "phone": phone,
                "website": f"https://www.{name.lower().replace(' ', '')}.example",
            },
        )
        contact = upsert(
            "res.partner",
            [("ref", "=", f"{PREFIX}CONTACT-{index:03d}")],
            {
                "name": ["Avery Johnson", "Morgan Lee", "Jordan Smith", "Taylor Brown",
                         "Casey Wilson", "Riley Davis", "Jamie Miller", "Cameron Moore"][index - 1],
                "ref": f"{PREFIX}CONTACT-{index:03d}",
                "parent_id": partner.id,
                "type": "contact",
                "email": email.replace("procurement", "avery").replace("purchasing", "morgan"),
                "phone": phone,
            },
        )
        customers[index] = (partner, contact)

    vendors = {}
    for index, (name, city) in enumerate(
        [("Alpine Components", "San Jose"), ("Proseware Manufacturing", "Detroit"),
         ("Graphic Design Institute", "Miami"), ("City Power & Light", "Dallas")], 1
    ):
        vendors[index] = upsert(
            "res.partner",
            [("ref", "=", f"{PREFIX}VEND-{index:03d}")],
            {
                "name": name,
                "ref": f"{PREFIX}VEND-{index:03d}",
                "is_company": True,
                "company_type": "company",
                "supplier_rank": 1,
                "street": f"{400 + index} Industrial Avenue",
                "city": city,
                "country_id": country.id,
                "email": f"sales@{name.lower().replace(' ', '')}.example",
            },
        )
    return customers, vendors


def seed_products(vendors):
    categories = {
        "furniture": upsert("product.category", [("name", "=", "Demo / Furniture")], {"name": "Demo / Furniture"}),
        "equipment": upsert("product.category", [("name", "=", "Demo / Equipment")], {"name": "Demo / Equipment"}),
        "services": upsert("product.category", [("name", "=", "Demo / Services")], {"name": "Demo / Services"}),
        "components": upsert("product.category", [("name", "=", "Demo / Components")], {"name": "Demo / Components"}),
    }
    definitions = [
        ("DESK-120", "Ergonomic Standing Desk", "furniture", "consu", 899.00, 510.00),
        ("CHAIR-210", "Executive Mesh Chair", "furniture", "consu", 449.00, 230.00),
        ("TABLE-310", "Modular Conference Table", "furniture", "consu", 1299.00, 760.00),
        ("LAMP-110", "LED Task Lamp", "equipment", "consu", 89.00, 38.00),
        ("DOCK-410", "USB-C Universal Dock", "equipment", "consu", 219.00, 125.00),
        ("MON-270", "27-inch Business Monitor", "equipment", "consu", 329.00, 205.00),
        ("PANEL-001", "Bamboo Desktop Panel", "components", "consu", 180.00, 95.00),
        ("FRAME-001", "Adjustable Desk Frame", "components", "consu", 290.00, 175.00),
        ("INSTALL", "On-site Installation", "services", "service", 145.00, 65.00),
        ("DESIGN", "Workspace Design Workshop", "services", "service", 1200.00, 500.00),
        ("SUPPORT", "Annual Equipment Support", "services", "service", 600.00, 180.00),
        ("DELIVERY", "Priority Delivery", "services", "service", 95.00, 40.00),
    ]
    products = {}
    for code, name, category, product_type, price, cost in definitions:
        product_values = {
            "name": name,
            "default_code": f"{PREFIX}{code}",
            "categ_id": categories[category].id,
            "type": product_type,
            "sale_ok": True,
            "purchase_ok": product_type != "service",
            "list_price": price,
            "standard_price": cost,
            "description_sale": f"Contoso demo product: {name}",
        }
        if product_type != "service" and "is_storable" in env["product.template"]._fields:
            product_values["is_storable"] = True
        template = upsert(
            "product.template",
            [("default_code", "=", f"{PREFIX}{code}")],
            product_values,
        )
        if "is_published" in template._fields:
            template.is_published = True
        product = template.product_variant_id
        products[code] = product
        if product_type != "service":
            env["product.supplierinfo"].search(
                [("partner_id", "=", vendors[1].id), ("product_tmpl_id", "=", template.id)]
            ).unlink()
            env["product.supplierinfo"].create({
                "partner_id": vendors[1].id,
                "product_tmpl_id": template.id,
                "price": cost,
                "min_qty": 1,
            })
    return products


def seed_inventory(products):
    stock_location = env.ref("stock.stock_location_stock")
    quantities = {"DESK-120": 28, "CHAIR-210": 65, "TABLE-310": 12, "LAMP-110": 90,
                  "DOCK-410": 42, "MON-270": 35, "PANEL-001": 80, "FRAME-001": 75}
    for code, quantity in quantities.items():
        product = products[code]
        quant = env["stock.quant"].search(
            [("product_id", "=", product.id), ("location_id", "=", stock_location.id)], limit=1
        )
        current = quant.quantity if quant else 0
        if current != quantity:
            env["stock.quant"]._update_available_quantity(product, stock_location, quantity - current)


def seed_crm(customers):
    stages = env["crm.stage"].search([], order="sequence asc", limit=5)
    opportunities = [
        (1, "Headquarters workspace modernization", 48000, 70),
        (2, "Clinical offices equipment refresh", 32500, 45),
        (3, "New hotel conference rooms", 76000, 30),
        (4, "Retail operations expansion", 24000, 85),
        (5, "Campus collaboration spaces", 54000, 20),
        (6, "Branch ergonomic furniture rollout", 91000, 60),
        (7, "Holiday distribution center setup", 18500, 10),
        (8, "Dispatch office renovation", 28000, 50),
    ]
    for index, (customer_index, title, revenue, probability) in enumerate(opportunities, 1):
        partner, contact = customers[customer_index]
        upsert(
            "crm.lead",
            [("name", "=", f"{PREFIX}{title}")],
            {
                "name": f"{PREFIX}{title}",
                "type": "opportunity",
                "partner_id": partner.id,
                "contact_name": contact.name,
                "email_from": contact.email,
                "phone": contact.phone,
                "expected_revenue": revenue,
                "probability": probability,
                "stage_id": stages[min(index - 1, len(stages) - 1)].id if stages else False,
                "date_deadline": fields.Date.today() + timedelta(days=7 + index * 5),
                "description": "Qualified opportunity generated for the connected Contoso demo scenario.",
            },
        )


def seed_sales(customers, products):
    plans = [
        (1, "Q-APB-001", [("DESK-120", 8), ("CHAIR-210", 16), ("INSTALL", 2)], True),
        (2, "Q-NWH-001", [("DOCK-410", 12), ("MON-270", 12), ("SUPPORT", 1)], True),
        (3, "Q-FAB-001", [("TABLE-310", 4), ("CHAIR-210", 20), ("DESIGN", 1)], False),
        (4, "Q-AWR-001", [("LAMP-110", 30), ("DOCK-410", 15), ("DELIVERY", 1)], True),
        (5, "Q-LIT-001", [("DESK-120", 10), ("CHAIR-210", 10)], False),
    ]
    orders = []
    for customer_index, client_ref, lines, confirm in plans:
        partner, contact = customers[customer_index]
        order = env["sale.order"].search([("client_order_ref", "=", f"{PREFIX}{client_ref}")], limit=1)
        if not order:
            order = env["sale.order"].create({
                "partner_id": partner.id,
                "partner_invoice_id": partner.id,
                "partner_shipping_id": partner.id,
                "client_order_ref": f"{PREFIX}{client_ref}",
                "date_order": fields.Datetime.now() - timedelta(days=customer_index * 3),
                "note": f"Prepared for {contact.name} as part of the Contoso demo.",
                "order_line": [Command.create({
                    "product_id": products[code].id,
                    "product_uom_qty": quantity,
                    "price_unit": products[code].lst_price,
                }) for code, quantity in lines],
            })
        if confirm and order.state in ("draft", "sent"):
            order.action_confirm()
        orders.append(order)
    return orders


def seed_purchases(vendors, products):
    plans = [
        (1, "PO-ALP-001", [("PANEL-001", 50), ("FRAME-001", 50)]),
        (2, "PO-PRO-001", [("DOCK-410", 25), ("MON-270", 20)]),
    ]
    for vendor_index, reference, lines in plans:
        order = env["purchase.order"].search([("partner_ref", "=", f"{PREFIX}{reference}")], limit=1)
        if not order:
            order = env["purchase.order"].create({
                "partner_id": vendors[vendor_index].id,
                "partner_ref": f"{PREFIX}{reference}",
                "date_order": fields.Datetime.now() - timedelta(days=12 - vendor_index),
                "order_line": [Command.create({
                    "product_id": products[code].id,
                    "name": products[code].display_name,
                    "product_qty": quantity,
                    "product_uom": products[code].uom_po_id.id,
                    "price_unit": products[code].standard_price,
                    "date_planned": fields.Datetime.now() + timedelta(days=5),
                }) for code, quantity in lines],
            })
        if order.state in ("draft", "sent", "to approve"):
            order.button_confirm()


def seed_projects_and_people(customers):
    department = upsert("hr.department", [("name", "=", "Demo Solutions Team")], {"name": "Demo Solutions Team"})
    employees = []
    for index, (name, job) in enumerate(
        [("Alex Wilber", "Account Executive"), ("Megan Bowen", "Solution Architect"),
         ("Diego Siciliani", "Project Manager"), ("Nestor Wilke", "Field Engineer")], 1
    ):
        employees.append(upsert(
            "hr.employee",
            [("work_email", "=", f"demo.employee{index}@contoso.example")],
            {"name": name, "job_title": job, "department_id": department.id,
             "work_email": f"demo.employee{index}@contoso.example"},
        ))
    project = upsert(
        "project.project",
        [("name", "=", f"{PREFIX}Azure Peak Headquarters Rollout")],
        {"name": f"{PREFIX}Azure Peak Headquarters Rollout", "partner_id": customers[1][0].id},
    )
    for index, (name, days) in enumerate(
        [("Confirm floor plans", 3), ("Schedule product delivery", 8),
         ("Install workstations", 14), ("Customer acceptance review", 18)], 1
    ):
        upsert(
            "project.task",
            [("name", "=", f"{PREFIX}{name}"), ("project_id", "=", project.id)],
            {"name": f"{PREFIX}{name}", "project_id": project.id,
             "partner_id": customers[1][0].id,
             "date_deadline": fields.Date.today() + timedelta(days=days),
             "description": "Connected project task for the Contoso workspace rollout demo."},
        )
    return employees


def seed_operations(products, employees):
    equipment = upsert(
        "maintenance.equipment",
        [("serial_no", "=", f"{PREFIX}FORKLIFT-01")],
        {"name": "Demo Warehouse Forklift", "serial_no": f"{PREFIX}FORKLIFT-01",
         "employee_id": employees[-1].id},
    )
    upsert(
        "maintenance.request",
        [("name", "=", f"{PREFIX}Quarterly forklift inspection")],
        {"name": f"{PREFIX}Quarterly forklift inspection", "equipment_id": equipment.id,
         "request_date": fields.Date.today(), "schedule_date": fields.Datetime.now() + timedelta(days=10)},
    )

    brand = upsert("fleet.vehicle.model.brand", [("name", "=", "Contoso Demo Motors")], {"name": "Contoso Demo Motors"})
    model = upsert(
        "fleet.vehicle.model",
        [("name", "=", "Delivery Van DX"), ("brand_id", "=", brand.id)],
        {"name": "Delivery Van DX", "brand_id": brand.id, "vehicle_type": "car"},
    )
    upsert(
        "fleet.vehicle",
        [("license_plate", "=", "DEMO-ACI-01")],
        {"model_id": model.id, "license_plate": "DEMO-ACI-01", "driver_id": employees[-1].work_contact_id.id,
         "odometer": 18420},
    )

    bom = env["mrp.bom"].search([("code", "=", f"{PREFIX}BOM-DESK")], limit=1)
    if not bom:
        bom = env["mrp.bom"].create({
            "code": f"{PREFIX}BOM-DESK",
            "product_tmpl_id": products["DESK-120"].product_tmpl_id.id,
            "product_qty": 1,
            "type": "normal",
            "bom_line_ids": [
                Command.create({"product_id": products["PANEL-001"].id, "product_qty": 1}),
                Command.create({"product_id": products["FRAME-001"].id, "product_qty": 1}),
            ],
        })
    production = env["mrp.production"].search([("origin", "=", f"{PREFIX}MO-DESK-001")], limit=1)
    if not production:
        production = env["mrp.production"].create({
            "product_id": products["DESK-120"].id,
            "product_qty": 5,
            "product_uom_id": products["DESK-120"].uom_id.id,
            "bom_id": bom.id,
            "origin": f"{PREFIX}MO-DESK-001",
        })
        production.action_confirm()


def seed_invoices(customers, products):
    journal = env["account.journal"].search([("type", "=", "sale"), ("company_id", "=", env.company.id)], limit=1)
    if not journal:
        print("Realistic demo: no sales journal; invoice generation skipped")
        return
    for index in (1, 2):
        reference = f"{PREFIX}INV-CUST-{index:03d}"
        move = env["account.move"].search([("ref", "=", reference), ("move_type", "=", "out_invoice")], limit=1)
        if not move:
            product = products["CHAIR-210" if index == 1 else "DOCK-410"]
            move = env["account.move"].create({
                "move_type": "out_invoice",
                "partner_id": customers[index][0].id,
                "journal_id": journal.id,
                "invoice_date": fields.Date.today() - timedelta(days=index * 5),
                "invoice_date_due": fields.Date.today() + timedelta(days=25 - index * 5),
                "ref": reference,
                "invoice_line_ids": [Command.create({
                    "product_id": product.id,
                    "quantity": 4 + index,
                    "price_unit": product.lst_price,
                })],
            })
        if move.state == "draft":
            move.action_post()


def main():
    print("Realistic demo: creating connected Contoso business data")
    customers, vendors = seed_partners()
    products = seed_products(vendors)
    seed_inventory(products)
    seed_crm(customers)
    seed_sales(customers, products)
    seed_purchases(vendors, products)
    employees = seed_projects_and_people(customers)
    optional("operations, fleet, and manufacturing", lambda: seed_operations(products, employees))
    optional("customer invoices", lambda: seed_invoices(customers, products))
    env.cr.commit()
    print("Realistic demo: seed completed")


main()
