# GPT-4 Python API Interface

This Python interface makes it easy to generate chat completions using OpenAI's GPT-4 model. Customize your API call by adjusting parameters like temperature, top_p, max tokens, etc for more control over the output. 

Here, we encapsulate the OpenAI chat completion API and build a command line interface using `click`.

## Requirements

1. OpenAI Python v0.27.0
2. Click
3. Python 3.6 and above

## Installation

Clone the repository and install the requirements

```
TODO
```

- Set your `OPENAI_ORGANIZATION` and `OPENAI_API_KEY` in your environment variables.
## Usage

Pass your prompt as stdin, for example

```
$ echo Count from 1 to 10 | gpt
1, 2, 3, 4, 5, 6, 7, 8, 9, 10
```

## Recipes
This section mainly shows ways to futz with stdin
```
$ echo This is a prompt | gpt
$ cat prompt.txt | gpt
$ (echo This goes above the prompt file; cat prompt.txt;) | gpt
$ seq 10 | (echo This goes above counting 1 to 10; cat;) | gpt
```

## Example Parameters

Here is a description and example of some of the parameters you can use.

- `--model` : Specifies the AI model to use, for example 'gpt-4'.
- `--n` : Specifies how many chat completion choices to generate for each input message. E.g., `--n=3`
- `--temperature` : Sets the sampling temperature between 0 and 2. A lower temperature means lower randomness. E.g., `--temperature=1.0`
- `--stop` : Sets up to 4 sequences where the API will stop generating further tokens. E.g., `--stop='["\n","]"]`
- `--max-tokens`: Defines the maximum number of tokens to generate in the chat completion. E.g., `--max-tokens=200`
- `--user` : This is an identifier representing your end-user, serves to monitor and detect abuse. E.g., `--user=user123`

## Note
Refer to the OpenAI API documentation for an extensive list of the options you can apply to the API call.

## Feedback
File bugs, questions, or feature requests on github, or email me at tyler@blitzblitzblitz.com
