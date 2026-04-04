"""
Electronic Marketplace System - Backend API
Requirements: pip install flask flask-cors mysql-connector-python bcrypt
Run: python app.py
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
import mysql.connector
import bcrypt
import os
from datetime import datetime, timedelta

app = Flask(__name__)
CORS(app)

# ========================
# DB CONNECTION
# ========================
DB_CONFIG = {
    "host":     os.getenv("DB_HOST", "localhost"),
    "user":     os.getenv("DB_USER", "root"),
    "password": os.getenv("DB_PASS", ""),
    "database": "electromarket",
    "charset":  "utf8mb4",
}

def get_db():
    conn = mysql.connector.connect(**DB_CONFIG)
    conn.autocommit = False
    return conn

def query(sql, params=(), fetchone=False, commit=False):
    conn = get_db()
    cur = conn.cursor(dictionary=True)
    try:
        cur.execute(sql, params)
        if commit:
            conn.commit()
            return cur.lastrowid if cur.lastrowid else cur.rowcount
        return cur.fetchone() if fetchone else cur.fetchall()
    except Exception as e:
        conn.rollback()
        raise e
    finally:
        cur.close()
        conn.close()

def ok(data=None, msg="success", status=200):
    return jsonify({"status": "ok", "message": msg, "data": data}), status

def err(msg="error", status=400):
    return jsonify({"status": "error", "message": msg}), status

# ========================
# AUTH ROUTES
# ========================

@app.route("/api/register", methods=["POST"])
def register():
    d = request.get_json()
    name, email, pwd, regno = d.get("name"), d.get("email"), d.get("password"), d.get("regno")
    if not all([name, email, pwd]):
        return err("Name, email and password are required")
    if query("SELECT 1 FROM users WHERE email=%s", (email,), fetchone=True):
        return err("Email already registered", 409)
    hashed = bcrypt.hashpw(pwd.encode(), bcrypt.gensalt()).decode()
    uid = query(
        "INSERT INTO users(name,email,password,regno) VALUES(%s,%s,%s,%s)",
        (name, email, hashed, regno), commit=True
    )
    return ok({"user_id": uid, "name": name, "email": email}, "Registered successfully", 201)

@app.route("/api/login", methods=["POST"])
def login():
    d = request.get_json()
    user = query("SELECT * FROM users WHERE email=%s", (d.get("email"),), fetchone=True)
    if not user or not bcrypt.checkpw(d.get("password","").encode(), user["password"].encode()):
        return err("Invalid email or password", 401)
    return ok({
        "user_id": user["user_id"],
        "name":    user["name"],
        "email":   user["email"],
        "role":    user["role"],
        "regno":   user["regno"],
    })

# ========================
# PRODUCT ROUTES
# ========================

@app.route("/api/products", methods=["GET"])
def get_products():
    cat    = request.args.get("category")
    search = request.args.get("q")
    sort   = request.args.get("sort", "units_sold")  # price|rating|units_sold
    page   = int(request.args.get("page", 1))
    limit  = int(request.args.get("limit", 16))
    offset = (page - 1) * limit

    sql = """
        SELECT p.product_id, p.name, p.description, p.price, p.stock,
               c.name AS category, p.rating, p.units_sold, p.emoji
        FROM products p
        LEFT JOIN categories c ON p.cat_id = c.cat_id
        WHERE p.stock > 0
    """
    params = []
    if cat:
        sql += " AND c.name = %s"
        params.append(cat)
    if search:
        sql += " AND MATCH(p.name, p.description) AGAINST(%s IN BOOLEAN MODE)"
        params.append(f"+{search}*")

    allowed_sorts = {"price", "rating", "units_sold", "name"}
    sort = sort if sort in allowed_sorts else "units_sold"
    sql += f" ORDER BY p.{sort} DESC LIMIT %s OFFSET %s"
    params += [limit, offset]

    products = query(sql, params)
    return ok(products)

@app.route("/api/products/<int:pid>", methods=["GET"])
def get_product(pid):
    p = query(
        """SELECT p.*, c.name AS category
           FROM products p
           LEFT JOIN categories c ON p.cat_id = c.cat_id
           WHERE p.product_id = %s""",
        (pid,), fetchone=True
    )
    if not p:
        return err("Product not found", 404)
    reviews = query(
        """SELECT r.*, u.name AS reviewer
           FROM reviews r JOIN users u ON r.user_id=u.user_id
           WHERE r.product_id=%s ORDER BY r.review_date DESC""",
        (pid,)
    )
    p["reviews"] = reviews
    return ok(p)

@app.route("/api/categories", methods=["GET"])
def get_categories():
    cats = query("SELECT cat_id, name, icon FROM categories ORDER BY name")
    return ok(cats)

# Admin: add product
@app.route("/api/products", methods=["POST"])
def add_product():
    d = request.get_json()
    pid = query(
        "INSERT INTO products(name,description,price,stock,cat_id,emoji) VALUES(%s,%s,%s,%s,%s,%s)",
        (d["name"], d.get("description"), d["price"], d.get("stock",0), d.get("cat_id"), d.get("emoji")),
        commit=True
    )
    return ok({"product_id": pid}, "Product added", 201)

# Admin: update product
@app.route("/api/products/<int:pid>", methods=["PUT"])
def update_product(pid):
    d = request.get_json()
    query(
        "UPDATE products SET name=%s, price=%s, stock=%s WHERE product_id=%s",
        (d["name"], d["price"], d["stock"], pid), commit=True
    )
    return ok(msg="Product updated")

# ========================
# CART ROUTES
# ========================

@app.route("/api/cart/<int:uid>", methods=["GET"])
def get_cart(uid):
    items = query(
        """SELECT c.cart_id, c.qty, p.product_id, p.name, p.price, p.emoji, p.stock,
                  (c.qty * p.price) AS line_total
           FROM cart c
           JOIN products p ON c.product_id = p.product_id
           WHERE c.user_id = %s""",
        (uid,)
    )
    subtotal = sum(float(i["line_total"]) for i in items)
    return ok({"items": items, "subtotal": subtotal, "tax": round(subtotal*0.18, 2),
               "total": round(subtotal*1.18, 2)})

@app.route("/api/cart", methods=["POST"])
def add_to_cart():
    d = request.get_json()
    uid, pid, qty = d["user_id"], d["product_id"], d.get("qty", 1)
    # Check stock
    prod = query("SELECT stock FROM products WHERE product_id=%s", (pid,), fetchone=True)
    if not prod or prod["stock"] < qty:
        return err("Insufficient stock")
    # Upsert
    query(
        """INSERT INTO cart(user_id, product_id, qty) VALUES(%s,%s,%s)
           ON DUPLICATE KEY UPDATE qty = qty + %s""",
        (uid, pid, qty, qty), commit=True
    )
    return ok(msg="Added to cart")

@app.route("/api/cart/<int:uid>/<int:pid>", methods=["DELETE"])
def remove_from_cart(uid, pid):
    query("DELETE FROM cart WHERE user_id=%s AND product_id=%s", (uid, pid), commit=True)
    return ok(msg="Removed from cart")

@app.route("/api/cart/<int:uid>/<int:pid>", methods=["PATCH"])
def update_cart_qty(uid, pid):
    qty = request.get_json().get("qty", 1)
    if qty <= 0:
        query("DELETE FROM cart WHERE user_id=%s AND product_id=%s", (uid, pid), commit=True)
    else:
        query("UPDATE cart SET qty=%s WHERE user_id=%s AND product_id=%s", (qty, uid, pid), commit=True)
    return ok(msg="Cart updated")

# ========================
# ORDER ROUTES
# ========================

@app.route("/api/orders/<int:uid>", methods=["GET"])
def get_orders(uid):
    orders = query(
        """SELECT o.order_id, o.order_date, o.status, o.total_amt,
                  COUNT(oi.item_id) AS item_count
           FROM orders o
           JOIN order_items oi ON o.order_id = oi.order_id
           WHERE o.user_id = %s
           GROUP BY o.order_id
           ORDER BY o.order_date DESC""",
        (uid,)
    )
    for o in orders:
        o["items"] = query(
            """SELECT p.name, p.emoji, oi.qty, oi.price
               FROM order_items oi JOIN products p ON oi.product_id=p.product_id
               WHERE oi.order_id=%s""",
            (o["order_id"],)
        )
    return ok(orders)

@app.route("/api/orders", methods=["POST"])
def place_order():
    d = request.get_json()
    uid, shipping = d["user_id"], d.get("shipping", "")
    conn = get_db()
    cur  = conn.cursor(dictionary=True)
    try:
        # Create order
        cur.execute("INSERT INTO orders(user_id, status, shipping) VALUES(%s,'Processing',%s)",
                    (uid, shipping))
        oid = cur.lastrowid

        # Get cart
        cur.execute("""SELECT c.product_id, c.qty, p.price, p.stock
                       FROM cart c JOIN products p ON c.product_id=p.product_id
                       WHERE c.user_id=%s""", (uid,))
        cart_items = cur.fetchall()
        if not cart_items:
            conn.rollback()
            return err("Cart is empty")

        # Insert order items (triggers will reduce stock)
        for item in cart_items:
            if item["stock"] < item["qty"]:
                conn.rollback()
                return err(f"Insufficient stock for product {item['product_id']}")
            cur.execute(
                "INSERT INTO order_items(order_id,product_id,qty,price) VALUES(%s,%s,%s,%s)",
                (oid, item["product_id"], item["qty"], item["price"])
            )

        # Update order total (with 18% GST)
        cur.execute(
            "UPDATE orders SET total_amt=(SELECT ROUND(SUM(qty*price)*1.18,2) FROM order_items WHERE order_id=%s) WHERE order_id=%s",
            (oid, oid)
        )

        # Clear cart
        cur.execute("DELETE FROM cart WHERE user_id=%s", (uid,))
        conn.commit()
        return ok({"order_id": oid}, "Order placed successfully", 201)
    except Exception as e:
        conn.rollback()
        return err(str(e))
    finally:
        cur.close()
        conn.close()

@app.route("/api/orders/<int:oid>/status", methods=["PATCH"])
def update_order_status(oid):
    status = request.get_json().get("status")
    valid  = ("Processing", "Shipped", "Delivered", "Cancelled")
    if status not in valid:
        return err(f"Status must be one of {valid}")
    query("UPDATE orders SET status=%s WHERE order_id=%s", (status, oid), commit=True)
    return ok(msg=f"Order status updated to {status}")

# ========================
# RECOMMENDATION ROUTE
# ========================

@app.route("/api/recommendations/<int:uid>", methods=["GET"])
def get_recommendations(uid):
    """
    SQL-based recommendation:
    Products from categories the user has purchased,
    excluding already-bought products, sorted by popularity.
    """
    recs = query("""
        SELECT
            p.product_id,
            p.name,
            p.price,
            p.emoji,
            c.name AS category,
            p.rating,
            p.units_sold,
            COUNT(oi2.product_id) AS global_freq
        FROM products p
        JOIN categories c ON p.cat_id = c.cat_id
        JOIN order_items oi2 ON p.product_id = oi2.product_id
        WHERE p.cat_id IN (
            SELECT DISTINCT pr.cat_id
            FROM orders o
            JOIN order_items oi ON o.order_id = oi.order_id
            JOIN products pr ON oi.product_id = pr.product_id
            WHERE o.user_id = %s AND o.status != 'Cancelled'
        )
        AND p.product_id NOT IN (
            SELECT oi3.product_id
            FROM orders o3
            JOIN order_items oi3 ON o3.order_id = oi3.order_id
            WHERE o3.user_id = %s AND o3.status != 'Cancelled'
        )
        AND p.stock > 0
        GROUP BY p.product_id, p.name, p.price, p.emoji, c.name, p.rating, p.units_sold
        ORDER BY global_freq DESC, p.rating DESC
        LIMIT 8
    """, (uid, uid))

    # Fallback: top-selling products if no history
    if not recs:
        recs = query(
            """SELECT p.product_id, p.name, p.price, p.emoji,
                      c.name AS category, p.rating, p.units_sold
               FROM products p JOIN categories c ON p.cat_id=c.cat_id
               WHERE p.stock > 0 ORDER BY p.units_sold DESC LIMIT 8"""
        )
    return ok(recs)

# ========================
# REVIEW ROUTES
# ========================

@app.route("/api/reviews", methods=["POST"])
def add_review():
    d = request.get_json()
    uid, pid, rating, comment = d["user_id"], d["product_id"], d.get("rating",5), d.get("comment","")
    # Only allow review if user purchased the product
    bought = query(
        """SELECT 1 FROM orders o JOIN order_items oi ON o.order_id=oi.order_id
           WHERE o.user_id=%s AND oi.product_id=%s AND o.status='Delivered' LIMIT 1""",
        (uid, pid), fetchone=True
    )
    if not bought:
        return err("You can only review products you have purchased and received", 403)
    query(
        """INSERT INTO reviews(user_id,product_id,rating,comment) VALUES(%s,%s,%s,%s)
           ON DUPLICATE KEY UPDATE rating=%s, comment=%s, review_date=CURRENT_DATE""",
        (uid, pid, rating, comment, rating, comment), commit=True
    )
    # Update product rating via procedure
    query("CALL UpdateProductRating(%s)", (pid,), commit=True)
    return ok(msg="Review submitted")

# ========================
# ADMIN ROUTES
# ========================

@app.route("/api/admin/stats", methods=["GET"])
def admin_stats():
    stats = {
        "total_revenue": query(
            "SELECT COALESCE(SUM(total_amt),0) AS v FROM orders WHERE status!='Cancelled'",
            fetchone=True
        )["v"],
        "total_orders": query("SELECT COUNT(*) AS v FROM orders", fetchone=True)["v"],
        "total_users":  query("SELECT COUNT(*) AS v FROM users WHERE role='customer'", fetchone=True)["v"],
        "total_products": query("SELECT COUNT(*) AS v FROM products", fetchone=True)["v"],
        "low_stock":    query("SELECT COUNT(*) AS v FROM products WHERE stock < 10", fetchone=True)["v"],
        "revenue_by_category": query("""
            SELECT c.name AS category, COALESCE(SUM(oi.qty*oi.price),0) AS revenue
            FROM categories c
            LEFT JOIN products p ON c.cat_id=p.cat_id
            LEFT JOIN order_items oi ON p.product_id=oi.product_id
            LEFT JOIN orders o ON oi.order_id=o.order_id AND o.status!='Cancelled'
            GROUP BY c.name ORDER BY revenue DESC
        """),
    }
    return ok(stats)

# ========================
# HEALTH CHECK
# ========================

@app.route("/api/health", methods=["GET"])
def health():
    try:
        query("SELECT 1", fetchone=True)
        return ok({"db": "connected", "time": datetime.now().isoformat()})
    except Exception as e:
        return err(str(e), 500)

# ========================
# MAIN
# ========================

if __name__ == "__main__":
    print("=" * 50)
    print("  ElectroMarket Backend API")
    print("  CSS 2212 DBS Lab Mini Project")
    print("  Running on http://localhost:5000")
    print("=" * 50)
    app.run(debug=True, port=5000)
