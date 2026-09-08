import tkinter as tk
from tkinter import messagebox
import webbrowser
import urllib.parse

def search():
    name = entry_name.get()
    dob = entry_dob.get()
    phone = entry_phone.get()
    email = entry_email.get()
    address = entry_address.get()

    query_parts = [name, dob, phone, email, address]
    query = " ".join([q for q in query_parts if q.strip() != ""])
    encoded_query = urllib.parse.quote_plus(query)

    # Open safe search URLs in browser tabs
    webbrowser.open(f"https://www.google.com/search?q={encoded_query}")
    webbrowser.open(f"https://www.bing.com/search?q={encoded_query}")
    webbrowser.open(f"https://www.linkedin.com/search/results/all/?keywords={encoded_query}")
    webbrowser.open(f"https://www.facebook.com/search/top?q={encoded_query}")
    webbrowser.open(f"https://www.instagram.com/explore/tags/{encoded_query.replace('+', '')}/")

    messagebox.showinfo("Search", "Search queries opened in your browser.")

# UI setup
root = tk.Tk()
root.title("Social Media Search Agent")

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