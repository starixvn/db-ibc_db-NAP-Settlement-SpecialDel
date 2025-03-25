from flask import Flask, request, jsonify
import os
import sys
import json
import pyodbc
from llama_cpp import Llama
from vector_DB_v4 import search_business_data, load_csv_to_vector_db
sys.stderr = open(os.devnull, 'w')

app = Flask(__name__)

# ✅ Danh sách các server và database
SQL_SERVERS = {
    "server2": {
        "server": "TESTDBPRO",
        "database": "bodb02",
        "username": "vnteam",
        "password": "@readonly#"
    },
    "server1": {
        "server": "TESTDBTRANS",
        "database": "bodb02",
        "username": "vnteam",
        "password": "@readonly#"
    }
}

def get_sql_connection(server_key):
    """Tạo kết nối SQL Server từ cấu hình linh hoạt"""
    config = SQL_SERVERS.get(server_key)
    if not config:
        raise ValueError(f"Server {server_key} không tồn tại!")

    connection_string = f"DRIVER={{ODBC Driver 17 for SQL Server}};SERVER={config['server']};DATABASE={config['database']};UID={config['username']};PWD={config['password']};TrustServerCertificate=yes;"
    
    return pyodbc.connect(connection_string)

# Load data from CSV
csv_path = r"D:\AI_Research\Separate\bettype_capture.csv"
load_csv_to_vector_db(csv_path)

# Load model GGUF (CapybaraHermes)
llama_model_path = r"D:\AI_Research\models\CapybaraHermes\capybarahermes-2.5-mistral-7b.Q8_0.gguf"
llama_model = Llama(model_path=llama_model_path, n_ctx=4096, n_threads=8)

def identify_entities(question):
    """Using Llama to identify matchid, output is JSON format."""
    prompt = f"""
        You are an AI assistant specialized in analyzing user queries to extract match IDs when they are present.

        🎯 Your task:
        - Detect and extract **match ID(s)** from the user's question.
        - A match ID is a numerical value (typically 6–10 digits) related to a football match, event, or game.
        - Ignore other numbers like **customer IDs (custid)** or **bet type IDs**, which are unrelated.

        📌 Example 1:
        User Query: "What is the status of match 83531115 and 83737754?"
        ✅ Output:
        {{ "matchid": "83531115, 83737754" }}

        📌 Example 2:
        User Query: "Check the bettype 470 and custid 123456."
        ✅ Output:
        {{ }}

        📌 Example 3:
        User Query: "What happened in match 83738106?"
        ✅ Output:
        {{ "matchid": "83738106" }}

        ---

        Now analyze the following query:

        🧠 User Query: "{question}"

        🔽 Instructions:
        - Return valid JSON only.
        - Do **not** include any explanation or extra text.
        - If no match ID is found, return empty JSON: `{{}}`

        🧾 Response:
        """

    response = llama_model(prompt, max_tokens=100, temperature=0.1, echo=False)
    llama_output = response["choices"][0]["text"].strip()

    json_start = llama_output.find("{")
    if json_start != -1:
        llama_output = llama_output[json_start:]

    try:
        extracted_info = json.loads(llama_output) 
        matchid = extracted_info.get("matchid", "").strip()

        matchid_list = [mid.strip() for mid in matchid.split(",") if mid.strip().isdigit()]
        return {"matchid": matchid_list} if matchid_list else {"matchid": None}
    
    except json.JSONDecodeError:
        return {"matchid": None}

def generate_llama_answer(question, search_results=None, has_matchid=False ):
    """Using Llama to generate answer base on SQL or Vector DB (if exist)."""
    prompt = ""
    if has_matchid and search_results and isinstance(search_results, dict):
        error_info = ""
        event_status = ""
        bet_summary = ""

        for key, records in search_results.items():
            if not records:
                continue

            print(f"[DEBUG] Processing key: {key} with {len(records)} records")

            if key.endswith("query_1"):  # Match status
                event_status += "\n".join(
                    f"{str(r.get('matchid', ''))}: {str(r.get('eventstatus', ''))}" for r in records
                ) + "\n"

            elif key.endswith("query_3"):  # AutoPayout errors (was previously query_2!)
                lines = []
                for r in records:
                    line = str(r.get("text", "") or "").strip()
                    if line:
                        lines.append(line)
                    else:
                        print("[WARN] query_3 record missing 'text':", r)
                error_info += "\n".join(lines) + "\n"

            elif key.endswith("query_2"):  # Bet ticket summary (was previously query_3!)
                lines = []
                for r in records:
                    mid = str(r.get("matchid", "") or "")
                    status = str(r.get("ticket status", "") or "")
                    count = str(r.get("", "") or "")  # Vì cột count bị ghi sai tên
                    line = f"{mid}  {status}  {count}".strip()
                    if mid and status and count:
                        lines.append(line)
                    else:
                        print("[WARN] query_2 record missing field:", r)
                bet_summary += "\n".join(lines) + "\n"
        if not error_info.strip() and not event_status.strip() and not bet_summary.strip():
            prompt = f"""
            You are a helpful AI assistant. The user asked about match ID(s), but no related data was found in the system.

            💡 User's Question:
            {question}

            🎯 Instructions:
            - Politely inform the user that there's no information available for the match ID(s) they provided.
            - Keep your response **short** and **clear**.
            - Do **not** make up any information.

            🔍 Response:
            """
        else:
            prompt = f"""
            You are a helpful AI assistant. Your task is to summarize the event status and errors of football matches based on structured data provided.

            📌 **Data from Multiple Sources**:
            1. **Error Log**:
            {error_info.strip() or 'No errors found.'}

            2. **Match Status**:
            {event_status.strip() or 'No status found.'}

            3. **Bet Ticket Summary**:
            {bet_summary.strip() or 'No ticket data available.'}

            💡 **User's Question**:
            {question}

            🎯 **Instructions**:
            - Summarize clearly the current **event status** of each match ID.
            - Mention if a match has any **Auto Payout errors**.
            - List bet ticket statuses such as WIN/LOSE/RUNNING if available.
            - Do **not** make up information or assume anything.
            - The tone should be **brief**, **neutral**, and **factual**.

            🔍 **Response**:
            """
    elif  has_matchid == False and search_results:
        context = "\n".join([
            f"- {res.get('Name', 'Unknown')}: {res.get('Description', 'No description available')} "
            f"(Option: {res.get('Option', 'N/A')}, Detail: {res.get('Detail', 'N/A')})"
            for res in search_results
        ])
        prompt = f"""
                You are a helpful AI assistant. Your task is to provide clear and concise answers based on the given data.

                📌 **Relevant Business Data**:
                {context}

                💡 **User's Question**:
                {question}

                🎯 **Instructions**:
                - Keep your response **concise** and **accurate**.
                - If the provided data is relevant, **use it to support your answer**.
                - If you don’t have enough data, **politely inform the user** instead of making up an answer.

                🔍 **Response**:
                """ 
    else:
        prompt = f"""
                You are a helpful AI assistant. Your task is to answer user questions accurately.

                💡 **User's Question**:
                {question}

                🎯 **Instructions**:
                - If you have insufficient information, inform the user.
                - Keep your response **concise** and **relevant**.

                🔍 **Response**:
                """

    response = llama_model(prompt, max_tokens=1000, temperature=0.7, top_p=0.9, echo=False)
    bot_reply = response["choices"][0]["text"].strip()
    bot_reply = bot_reply.replace("\n", " ").strip()
    return bot_reply


def generate_sql_query(extracted_info):
    """Generate SQL query base on extracted data."""
    conditions = []
    
    if extracted_info.get("matchid"):
        matchids = extracted_info["matchid"]
        if isinstance(matchids, list) and matchids:
            matchid_str = ", ".join(f"'{mid}'" for mid in matchids) 
            conditions.append(f"matchid IN ({matchid_str})")
        elif isinstance(matchids, str):
            conditions.append(f"matchid = '{matchids}'")
    
    if not conditions:
        return None, None, None
    
    query1 = f"SELECT top 100 matchid, eventstatus FROM match WITH (NOLOCK) WHERE {' AND '.join(conditions)}"

    query2 = f"""select matchid,status as 'ticket status', count(1)
                    from bettrans
                    where matchid in ({matchid_str})
                    group by matchid,status
                    """
    
    query3 = f"""select 'MatchID ' + CONVERT(VARCHAR(25), ap.matchid) + '  has error: ' + ap.remark AS text,m.MatchId
                from AutoPayoutResult as ap with(nolock)
                    left join match as m with(nolock)   on ap.MatchId = m.MatchId
                where  ap.StatusId = 3
                    and ap.Remark is not null
                    and ap.MatchId in ({matchid_str})
                union
                select 'MatchID ' + CONVERT(VARCHAR(25), ap.matchid) + '  has error: ' + ap.remark AS text,m.MatchId
                from AutoPayoutResultOS as ap with(nolock)
                    left join match as m with(nolock)   on ap.MatchId = m.MatchId
                where ap.StatusId = 3
                    and ap.Remark is not null
                    and ap.MatchId in ({matchid_str})"""
    
    return query1, query2, query3

def query_database(extracted_info):
    """Thực thi các câu truy vấn với server cố định."""
    try:
        all_results = {}
        queries = generate_sql_query(extracted_info)  # ✅ Lấy danh sách query

        if not queries or all(q is None for q in queries):  # ✅ Kiểm tra nếu không có query hợp lệ
            return "No valid query generated."

        # ✅ Chạy query 1 và query 2 trên server1
        server_key = "server1"
        conn = get_sql_connection(server_key)
        cursor = conn.cursor()
        
        for i in [1, 2]:  # ✅ Chạy query 1 và 2 trên server1
            sql_query = queries[i - 1]
            if sql_query:
                print(f"[DEBUG] Executing Query {i} on {server_key}: {sql_query}")
                cursor.execute(sql_query)
                result = cursor.fetchall()
                column_names = [column[0] for column in cursor.description] if result else []

                formatted_result = [
                    {column_names[j]: row[j] for j in range(len(column_names))}
                    for row in result
                ]
                
                print(f"[DEBUG] Query {i} results from {server_key}:", formatted_result)
                all_results[f"{server_key}_query_{i}"] = formatted_result
        
        conn.close()
        
        # ✅ Chạy query 3 trên server2
        server_key = "server2"
        conn = get_sql_connection(server_key)
        cursor = conn.cursor()
        
        sql_query = queries[2]  # ✅ Query 3
        if sql_query:
            print(f"[DEBUG] Executing Query 3 on {server_key}: {sql_query}")
            cursor.execute(sql_query)
            result = cursor.fetchall()
            column_names = [column[0] for column in cursor.description] if result else []

            formatted_result = [
                {column_names[j]: row[j] for j in range(len(column_names))}
                for row in result
            ]
            
            print(f"[DEBUG] Query 3 results from {server_key}:", formatted_result)
            all_results[f"{server_key}_query_3"] = formatted_result
        
        conn.close()
        
        return all_results if all_results else "No data found."

    except Exception as e:
        return f"Error executing SQL query: {str(e)}"



@app.route("/chat", methods=["POST"])
def chat():
    data = request.get_json()
    if not data or 'message' not in data:
        return jsonify({"error": "Invalid request. Please provide a 'message'."}), 400
    
    text = data['message'].strip()
    responses = []   
    extracted_info = identify_entities(text)

    if extracted_info.get("matchid"):
        db_results = query_database(extracted_info) 

        if isinstance(db_results, list) or any(db_results.values()) or db_results:
            llama_answer = generate_llama_answer(text, db_results, has_matchid=True)
            responses.append(llama_answer)
        else:
            responses.append("No relevant data found in the database.")

    else:
        search_results = search_business_data(text)

        if search_results:
            llama_answer = generate_llama_answer(text, search_results, has_matchid=False)
        else:
            llama_answer = generate_llama_answer(text)
        
        responses.append(llama_answer)

    return jsonify({"response": responses})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001, debug=True)
