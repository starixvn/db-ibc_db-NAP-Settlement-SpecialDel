import llama_cpp
import sys
import os
sys.stderr = open(os.devnull, 'w')

def test_model_responses(prompt):
    model = llama_cpp.Llama(model_path=r"D:\AI_Research\models\CapybaraHermes\capybarahermes-2.5-mistral-7b.Q8_0.gguf")  # Cập nhật đường dẫn model

    test_cases = [
        {"temperature": 0.7, "top_p": 0.9},
        {"temperature": 1.0, "top_p": 1.0},
        {"temperature": 1.5, "top_p": 0.9},
    ]

    for case in test_cases:
        print(f"\n### Testing with temperature={case['temperature']}, top_p={case['top_p']}\n")
        response = model(
            prompt,
            max_tokens=200,  # Tăng số token để mô hình có đủ không gian sinh văn bản
            temperature=case["temperature"],
            top_p=case["top_p"],
            echo=False
        )
        print(response["choices"][0]["text"].strip())

if __name__ == "__main__":
    test_prompt = """
                        Base on the message below, please identity the matchid, bettype, team, game, error type, and retry time.
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
                            
                            """
    test_model_responses(test_prompt)
