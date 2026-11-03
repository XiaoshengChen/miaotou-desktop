"""Check the curated source tree without printing potential secret values."""
from pathlib import Path
import re, sys
root = Path(__file__).resolve().parents[1]
ignored = {'.git', '.build', 'bin', 'obj', 'dist', 'artifacts', '__pycache__'}
patterns = {
 'local home path': r'(?:/Users/|/home/|C:\\\\Users\\\\)',
 'private key': r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',
 'GitHub token': r'\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})',
 'cloud API key': r'\b(?:sk-[A-Za-z0-9_-]{20,}|AKIA[A-Z0-9]{16}|AIza[A-Za-z0-9_-]{25,})',
 'configured secret': r'(?i)(?:api[_-]?key|access[_-]?token|client[_-]?secret|password)\s*[=:]\s*[\"\x27][A-Za-z0-9_\-/+=]{12,}[\"\x27]',
 'personal email': r'(?i)[A-Z0-9._%+-]+@(?:gmail|outlook|hotmail|qq|icloud)\.com',
}
errors=[]
for p in root.rglob('*'):
 if not p.is_file() or any(part in ignored for part in p.relative_to(root).parts) or p == Path(__file__).resolve(): continue
 rel=p.relative_to(root)
 if p.suffix.lower() in {'.p12','.p8','.key','.pem','.mobileprovision','.provisionprofile','.pdb'} or p.name.startswith('.env'):
  errors.append((str(rel),'forbidden file'));continue
 try: content=p.read_text(encoding='utf-8')
 except (UnicodeError,OSError): continue
 for name,pattern in patterns.items():
  if re.search(pattern,content):errors.append((str(rel),name))
for rel,name in errors:print(f'FAIL {rel}: {name}')
print(f'Public source check: {len(errors)} findings')
sys.exit(bool(errors))
