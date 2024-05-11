# Word Cloud
Создает облако тэгов из текстового файла

# Install
```
# Install venv
sudo apt install python3.8-venv

# create dir
mkdir ~/tag_cloud
cd ~/tag_cloud/

# Create Virtual_Environment for pkg
python3 -m venv ./

# Activate Virtual_Environment
. bin/activate

# copy from git
cp ~/git/my_scripts/python/word_cloud/* ~/tag_cloud/

# Install modules
pip3 install wordcloud pillow==9.4.0
# or
pip3 install -r requirements.txt
```

# Usage
```
# Add text file
vim task.txt

# Run
time python3 word_cloud.py
```
