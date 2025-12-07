# Importing Libraries
import os
import json
import time
import asyncio
import pandas as pd
from datetime import datetime
from openai import AsyncOpenAI
from tqdm.asyncio import tqdm as async_tqdm
import pandas as pd

# Defining Parameters for the OpenAI Model
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "KEY")
MODEL_NAME = "gpt-4o-mini"
PROMPT_FILE = "3_extraction/prompt.txt"
OUTPUT_DIR = "data/extract/openai_extracted_text"
BATCH_SIZE = 10
BATCH_DELAY = 0.1

# ------------------- Setting up directories ----------------------------------
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Defining timestamp
timestamp = datetime.now().strftime("%Y%m%d")

# Loading data
df = pd.read_csv("data/overview_data/filtered_texts.csv")

# Load prompt template
with open(PROMPT_FILE, "r", encoding="utf-8") as f:
    prompt_template = f.read()

# Initialize async client
client = AsyncOpenAI(api_key=OPENAI_API_KEY)

# ------------------- Detecting already saved files ----------------------------

# Creating list of already used files.
existing_file_ids = set()
for fname in os.listdir(OUTPUT_DIR):
    if not fname.endswith(".txt"):
        continue
    parts = fname.split("_")
    if len(parts) >= 1:
        existing_file_ids.add(parts[0])
        
        %>%
        
# ------------------- Defining Async Process to loop through -------------------
async def process_single_row(row, index, semaphore):
    async with semaphore: 
        file_id = row.get("file_id", f"index{index}")
        if file_id in existing_file_ids:
            return {"status": "skipped", "file_id": file_id, "reason": "already_saved"}
        complaint = row["text_content"]
        
        # Validating that not empty
        if not isinstance(complaint, str) or len(complaint) == 0:
            return {"status": "skipped", "file_id": file_id, "reason": "empty_text"}

        # Preparing prompt
        extraction_prompt = prompt_template.replace("{complaint_text}", complaint)
        
        # Timing requests
        start_time = time.perf_counter()
        
        try:
            response = await client.chat.completions.create(
                model=MODEL_NAME,
                messages=[
                    {
                        "role": "system", 
                        "content": "You are a legal data extraction system. Respond ONLY with valid JSON."
                    },
                    {
                        "role": "user", 
                        "content": extraction_prompt
                    }
                ],
                temperature=0
            )
            
            output_text = response.choices[0].message.content
            
            # Saving the output as txt
            save_path = os.path.join(
                OUTPUT_DIR,
                f"{file_id}_{MODEL_NAME}_{timestamp}.txt"
            )
            
            with open(save_path, "w", encoding="utf-8") as f:
                f.write(output_text)
            
            elapsed = time.perf_counter() - start_time
            
            return {
                "status": "success",
                "file_id": file_id,
                "time": elapsed,
                "tokens": response.usage.total_tokens if hasattr(response, 'usage') else None
            }
            
        except Exception as e:
            elapsed = time.perf_counter() - start_time
            return {
                "status": "error",
                "file_id": file_id,
                "error": str(e),
                "time": elapsed
            }

# ------------------- Defining the async main ---------------------------------
async def openai_main():
    total_start = time.perf_counter()
    semaphore = asyncio.Semaphore(BATCH_SIZE)
    
    tasks = [
        process_single_row(row, i, semaphore) 
        for i, row in df.iterrows()
    ]
    
    results = []
    for i in range(0, len(tasks), BATCH_SIZE):
        batch = tasks[i:i + BATCH_SIZE]
        batch_results = await asyncio.gather(*batch)
        results.extend(batch_results)

        for result in batch_results:
            if result["status"] == "success":
                print(f"✓ {result['file_id']} - {result['time']:.2f}s - {result.get('tokens', 'N/A')} tokens")
            elif result["status"] == "skipped":
                print(f"⊘ {result['file_id']} - {result['reason']}")
            else:
                print(f"✗ {result['file_id']} - {result['error']}")

        if i + BATCH_SIZE < len(tasks):
            await asyncio.sleep(BATCH_DELAY)
    
    total_end = time.perf_counter()
    
    # Getting summary stat's
    success_count = sum(1 for r in results if r["status"] == "success")
    error_count = sum(1 for r in results if r["status"] == "error")
    skipped_count = sum(1 for r in results if r["status"] == "skipped")
    success_times = [r["time"] for r in results if r["status"] == "success"]
    avg_time = sum(success_times) / len(success_times) if success_times else 0
    total_tokens = sum(r.get("tokens", 0) or 0 for r in results if r["status"] == "success")
    
    print("\n" + "="*60)
    print(f"TOTAL RUNTIME: {total_end - total_start:.2f} seconds")
    print(f"Successful: {success_count} | Errors: {error_count} | Skipped: {skipped_count}")
    print(f"Average time per request: {avg_time:.2f}s")
    print(f"Total tokens used: {total_tokens:,}")
    print(f"Throughput: {success_count / (total_end - total_start):.2f} files/second")
    print("="*60)
    
    # Saving the summary stats
    summary = {
        "timestamp": timestamp,
        "total_runtime": total_end - total_start,
        "success_count": success_count,
        "error_count": error_count,
        "skipped_count": skipped_count,
        "avg_time_per_request": avg_time,
        "total_tokens": total_tokens,
        "results": results
    }
    
    # Outputting the summary stats
    summary_path = os.path.join(OUTPUT_DIR, f"summary_{timestamp}.json")
    with open(summary_path, "w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2)
  
# -------------------------- Running the Function ------------------------------
if __name__ == "__main__":
    print(f"Starting extraction for {len(df)} files...")
    print(f"Batch size: {BATCH_SIZE} concurrent requests")
    print(f"Model: {MODEL_NAME}\n")
    
    asyncio.run(openai_main())
