""" Generate WordCloud.png from txt """
# pylint: disable=import-error
from pathlib import Path
#import matplotlib.pyplot as plt
from wordcloud import STOPWORDS, WordCloud


def get_stop_words_from_file(txt_file):
    """
    Get Stop Words from file
    input txt_file: path to txt file
    return: stop words set
    """
    stop_words = set(STOPWORDS)
    with open(txt_file, 'r', encoding="utf-8") as text_file:
        for stop_word in text_file.readlines():
            if not '#' in stop_word:
                stop_words.add(stop_word.rstrip())
    return stop_words


def add_stop_words(stop_words):
    """
    Add stop words to stop_words set
    input stop_words: stop_words set
    return: stop words set
    """
    stop_words.add("сервера")
    return stop_words


def main(txt_file, stop_words_file):
    """
    Generate WorldCloud.png from txt_file
    input txt_file: path to txt file
    input stop_words_file: path to txt file with stop_words
    """

    # Read text
    with open(txt_file, 'r', encoding="utf-8") as text_file:
        text = text_file.read()

    # Set StopWors
    stop_words = get_stop_words_from_file(stop_words_file)
    add_stop_words(stop_words)

    # Run WordCloud
    word_cloud = WordCloud(background_color="white",
                           stopwords=stop_words,
                           min_word_length=3,
                           height=1080,
                           width=1920)
    word_cloud.generate(text)

    # Store to file
    word_cloud.to_file("WordCloud.png")


if __name__ == '__main__':
    TXT_FILE = Path.cwd() / "tasks.txt"
    STOP_WORDS_FILE = Path.cwd() / "stop_words.txt"
    main(TXT_FILE, STOP_WORDS_FILE)
