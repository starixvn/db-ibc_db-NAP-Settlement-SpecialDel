from llama_cpp import Llama
import sys
import os
sys.stderr = open(os.devnull, 'w')

# ✅ Đường dẫn đến model GGUF đã tải về
model_path = r"D:\AI_Research\models\CapybaraHermes\capybarahermes-2.5-mistral-7b.Q8_0.gguf"

# ✅ Load model (tối ưu với 8 threads)
llm = Llama(model_path=model_path, n_ctx=4096, n_threads=8)

# ✅ Test câu hỏi
prompt = """
Extract the following information from the text:
- matchid
- bettype
- error (if available)
- team
- game

Return the result in JSON format.

Text:
------------------------------
hi team, hi @Jolie @Starix IT 
Dota 2 - DreamLeague
Team Falcons -vs- Heroic 
101136469
Map 2 Moneyline
-----------------------------------
Tennis
ATP Challenger - Brazzaville Challenger - Second Set Game Winner
Alec Beckley (RSA)(10th Game) -vs- Franco Agamenone (ITA)(10th Game)
101183624

2 bet types are "Failed Auto Payout" 
May we know why these two have failed if the retry time is 5 minutes? Thanks
------------------------------

hi @Jolie 
Volleyball
Argentina Liga Nacional
Normal 3 Voley de Rosario -vs- Obras San Juan Voley
99382917
 
The match was succeeded by Auto Payout, but the 'Full Time' score wasn't visible on either the Nap or member sites.
Please help check, thanks
------------------------------------
Hi pls help check on below match
 
Basketball - Germany Basketball Bundesliga 
Riesen Ludwigsburg -vs- Bamberg Baskets 
98836576
 
Quarter 3
 
System auto payout @11:48:10 AM but Ticket Status still display as Running?
--------------------------------------
 
hi @Starix 
Basketball
Indonesia Basketball League
RANS Simba Bogor -vs- Satya Wacana Salatiga 
98836415
Quarter 2 system auto keyed but on FInal score column dont show score
lead to system failed for calculate HT score due to Q2 not yet key
 
Can please help to check ,thanks
--------------------------------------

JSON Output:
"""
output = llm(prompt, max_tokens=1000, stream=True)

print("Chatbot:", end=" ")
for chunk in output:
    if "choices" in chunk and chunk["choices"]:
        print(chunk["choices"][0]["text"], end="", flush=True)
print()  # Xuống dòng khi kết thúc
