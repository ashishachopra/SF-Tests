import tkinter as tk
from tkinter import messagebox
import webbrowser
import urllib.parse

def search():
    name = entry_name.get().strip()
    dob = entry_dob.get().strip()
    phone = entry_phone.get().strip()
    email = entry_email.get().strip()
    address = entry_address.get().strip()

    # Build search terms with quotes for exact match highlighting
    search_terms = []
    for term in [name, dob, phone, email, address]:
        if term:
            search_terms.append(f'"{term}"')

    if not search_terms:
        messagebox.showwarning("Input Error", "Please enter at least one search field.")
        return

    # Combine into one query string
    query = " ".join(search_terms)

    # Social media site filters
    social_sites = [
        "site:linkedin.com",
        "site:facebook.com",
        "site:instagram.com",
        "site:twitter.com",
        "site:tiktok.com"
    ]

    # Create a combined filter query
    site_filter = " OR ".join(social_sites)

    # Final query with site restriction
    final_query = f"{query} ({site_filter})"
    encoded_query = urllib.parse.quote_plus(final_query)

    # Open in multiple search engines for redundancy
    webbrowser.open(f"https://www.google.com/search?q={encoded_query}")
    webbrowser.open(f"https://www.bing.com/search?q={encoded_query}")
    webbrowser.open(f"https://duckduckgo.com/?q={encoded_query}")

    messagebox.showinfo("Search", "Social media OSINT searches opened in your browser.")

# UI setup
root = tk.Tk()
root.title("Social Media OSINT Search Tool")

labels = ["Name", "Date of Birth", "Phone Number", "Email", "Address"]
entries = []

for label in labels:
    tk.Label(root, text=label).pack()
    entry = tk.Entry(root, width=50)
    entry.pack()
    entries.append(entry)

entry_name, entry_dob, entry_phone, entry_email, entry_address = entries

tk.Button(root, text="Search", command=search).pack(pady=10)

root.mainloop()
