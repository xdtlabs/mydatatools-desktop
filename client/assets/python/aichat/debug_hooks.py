from PyInstaller.utils.hooks import collect_all
import pprint

try:
    ret = collect_all('langchain_google_genai')
    print("Datas:")
    pprint.pprint(ret[0])
    print("\nBinaries:")
    pprint.pprint(ret[1])
    print("\nHidden Imports:")
    pprint.pprint(ret[2])
except Exception as e:
    print(f"Error: {e}")
