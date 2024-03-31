
API_KEY = "..."

import argparse
from openai import OpenAI
import time
from typing import Optional

from langchain.chains import create_structured_output_runnable
from langchain_openai import ChatOpenAI
from langchain_core.pydantic_v1 import BaseModel, Field
from langchain_core.output_parsers import JsonOutputParser

class PossibleSelectors(BaseModel):
    '''Possible CSS or XPath selectors for a given element'''

    type: str = Field(..., description="The type of selector")
    selector: str = Field(..., description="The selector itself")

client = OpenAI(api_key=API_KEY)

def main(name, description, html):
    # === Hardcode our ids ===
    asistant_id = "..."

    # ==== Retrieve the Assistant ====
    assistant = client.beta.assistants.retrieve(asistant_id)

    # ==== Create a Thread ====
    thread = client.beta.threads.create()

    # Set up a parser + inject instructions into the prompt template.
    parser = JsonOutputParser(pydantic_object=PossibleSelectors)

    # ==== Create a Message ====
    message = f"""
        name: ${name},
        description: ${description},
        html: ```
            ${html}
        ```,
    """
    message = client.beta.threads.messages.create(
        thread_id=thread.id, role="user", content=message
    )

    # === Run our Assistant ===
    run = client.beta.threads.runs.create(
        thread_id=thread.id,
        assistant_id=asistant_id,
        instructions=assistant.instructions,
        additional_instructions=
            "format_instructions: " + parser.get_format_instructions(),
    )

    while run.status in ['queued', 'in_progress', 'cancelling']:
        time.sleep(1) # Wait for 1 second
        run = client.beta.threads.runs.retrieve(
            thread_id=thread.id,
            run_id=run.id
        )

    if run.status == 'completed': 
        messages = client.beta.threads.messages.list(
            thread_id=thread.id
        )
        return [message.content for message in messages]

    return None
        
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Description of your program")
    parser.add_argument("--name", type=str, help="Name argument")
    parser.add_argument("--description", type=str, help="Description argument")
    parser.add_argument("--html", type=str, help="HTML argument")
    
    # Parse the command-line arguments and pass them to the main function
    args = parser.parse_args()
    response = main(args.name, args.description, args.html)
    print(response)



