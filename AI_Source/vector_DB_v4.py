import faiss
import numpy as np
import pandas as pd
import re
import torch
from sentence_transformers import SentenceTransformer

# Load model LaBSE
device = "cuda" if torch.cuda.is_available() else "cpu"
embedding_model = SentenceTransformer("sentence-transformers/LaBSE").to(device)

# Initialize FAISS Index for multiple columns
vector_dim = 768  
index_dict = {}  # Dictionary to store FAISS index for each column
column_embeddings = {}  # Dictionary to store embeddings for each column
business_data = []  # Store original data

# Normalize text for more accurate searching
def normalize_text(text):
    text = text.lower().strip()
    text = re.sub(r'[^\w\s]', '', text)
    return text

# Function to add data into multiple FAISS indexes
def add_business_data(row):
    global index_dict, business_data, column_embeddings

    try:
        record = {
            "Id": str(row["Id"]) if pd.notna(row["Id"]) else "Unknown",
            "Name": str(row["Name"]) if pd.notna(row["Name"]) else "Unknown",
            "Description": str(row["Description Of Bettype"]) if pd.notna(row["Description Of Bettype"]) else "N/A",
            "Option": str(row["Option"]) if pd.notna(row["Option"]) else "N/A",
            "Detail": str(row["Description of BetOption"]) if pd.notna(row["Description of BetOption"]) else "N/A",
            "BetTeam": str(row["betteam"]) if pd.notna(row["betteam"]) else "N/A",
            "Remark": str(row["Remark"]) if pd.notna(row["Remark"]) else "N/A",
        }

        business_data.append(record)

        # ✅ Encode text for multiple columns
        for column in ["Id", "Name", "Option", "Description", "Detail","BetTeam","Remark"]:
            if column not in index_dict:
                index_dict[column] = faiss.IndexFlatIP(vector_dim)
                column_embeddings[column] = []

            text_value = normalize_text(record[column])
            vector = embedding_model.encode([text_value], convert_to_tensor=True).to("cpu")
            vector = vector.detach().numpy().astype(np.float32).reshape(-1)
            vector /= np.linalg.norm(vector)  # Normalize vector before inserting into FAISS

            index_dict[column].add(np.array([vector], dtype=np.float32))  # Add vector to FAISS index
            column_embeddings[column].append(vector)

    except Exception as e:
        return

# Function to load csv data into multiple FAISS indexes
def load_csv_to_vector_db(csv_path):
    df = pd.read_csv(csv_path)
    required_columns = ["#", "Id", "Name", "Description Of Bettype", "Option", "Description of BetOption", "betteam", "Remark"]
    if not all(col in df.columns for col in required_columns):
        raise ValueError(f"CSV must have these columns {required_columns}!")

    for _, row in df.iterrows():
        add_business_data(row)

# Function to determine best column to search in
def determine_best_column(query_vector):
    best_column = None
    best_score = -1
    best_results = []

    for column, index in index_dict.items():
        if index.ntotal == 0:
            continue

        query_vector = query_vector.reshape(1, -1)

        D, I = index.search(query_vector, k=5)
        avg_score = np.mean(D[0]) 

        if avg_score > best_score:
            best_score = avg_score
            best_column = column
            best_results = I[0]

    return best_column, best_results

# Search function data in vector DB
def search_business_data(query, similarity_threshold=0.6):
    """Find the data in vector DB """
    global index_dict, business_data

    normalized_query = normalize_text(query)
    query_vector = embedding_model.encode([normalized_query], convert_to_tensor=True).cpu().numpy()

    query_vector = query_vector.reshape(1, -1)
    query_vector /= np.linalg.norm(query_vector)

    best_column, best_results = determine_best_column(query_vector)


    if best_results is None or len(best_results) == 0 or best_column is None:
        return None 


    results = [business_data[idx] for idx in best_results if idx != -1]
    return results if results else None


