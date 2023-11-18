# Adapted from example in https://www.udemy.com/course/the-modern-python3-bootcamp/

import requests
from bs4 import BeautifulSoup
from time import sleep
from random import choice

all_quotes = []
base_url= "https://quotes.toscrape.com"
url= "/page/1"

while url:
    res = requests.get(f"{base_url}{url}")
    print(f"Now Scraping {base_url}{url}....")
    soup = BeautifulSoup(res.text, "html.parser")
    quotes = soup.find_all(class_="quote")
    for quote in quotes:
        all_quotes.append({
            "text":quote.find(class_="text").get_text(),
            "author": quote.find(class_="author").get_text(),
            "bio-link": quote.find("a")["href"]
        })

    next_btn = soup.find(class_="next")
    url = next_btn.find("a")["href"] if next_btn else None

def start_game():
    quote = choice(all_quotes)
    remaining_guesses = 4
    print("Here's a quote: ")
    print(quote["text"])
    print(quote["author"])
    guess = ''
    while guess.lower() != quote["author"].lower() and remaining_guesses > 0:
        f"Who said this quote? Guesses remaining: {remaining_guesses}"
        guess = input()
        if guess.lower() == quote["author"].lower():
            print(f"Congrats you guessed it! It's {quote['author']}")
            print("-")
            # print(f"Here's a brief biography about {quote['author']} :\n")
            # print("-")
            # print(f"{soup.find(class_='author-description').split('.')[1:3]}...")
            break
        remaining_guesses -= 1
        if remaining_guesses == 3:
            res = requests.get(f"{base_url}{quote['bio-link']}")
            soup = BeautifulSoup(res.text, "html.parser")
            birth_date = soup.find(class_="author-born-date").get_text()
            birth_place = soup.find(class_="author-born-location").get_text()
            print(f"Sorry no, here's a hint: Author was born on {birth_date} {birth_place}")
        elif remaining_guesses == 2:
            print(f"Sorry no, here's a hint: Author's first name starts with {quote['author'][0:2]}") #takes the first letter of the author's first name (first character of second list)
        elif remaining_guesses == 1:
            last_intital = quote['author'].split(" ")[1][0:2] #takes the first letter of the author's last name
            print(f"Sorry no, here's a hint: Author's last name starts with {last_intital}")
        else:
            print
            (f"Sorry you are out of guesses, it was {quote['author']}\n")
            # print(f"Here's a brief biography about {quote['author']} :\n")
            # print("-")
            # print(f"{soup.find(class_='author-description').split('.')[1:3]}...")

        again = ''
    while again not in ('y', 'yes', 'n','no'):
        again = input("Would you like to Play again? (y/n)")
    if again.lower() in ('yes','y'):
        return start_game()
    else:


        print("Thanks for playing!")
        

start_game()

