from pathlib import Path
import urllib.request,re
import sys
base='https://atmos.nmsu.edu/PDS/data/PDS4/Mars2020/mars2020_meda/data_calibrated_env/sol_0000_0089/'
if len(sys.argv)>1: base=sys.argv[1]
s=urllib.request.urlopen(base,timeout=40).read().decode()
links=re.findall('href="([^"]+)"',s)
print('\n'.join(links[:65]) if links else s[:3000])
