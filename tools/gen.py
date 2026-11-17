# Builds product / category images from the Fruits-360 dataset (CC BY-SA 4.0).
import subprocess, os, sys, random, math
from PIL import Image, ImageFilter, ImageDraw, ImageChops, ImageOps
D = sys.argv[1]; OUT = sys.argv[2]
REPO = {'o': os.path.join(D, 'orig'), 's': os.path.join(D, 'small')}
_cache = {}

def files(ref):
    r, c = ref.split(':', 1)
    out = subprocess.run(['git', '-C', REPO[r], 'ls-tree', '-r', '--name-only', 'HEAD', 'Training/' + c + '/'], capture_output=True, text=True).stdout.split('\n')
    fs = sorted(f for f in out if f.endswith('.jpg'))
    if not fs: raise SystemExit('no files for ' + ref)
    return r, fs

def cutout(path):
    im = Image.open(path).convert('RGB')
    # foreground = clearly non-white pixels
    g = ImageOps.grayscale(ImageChops.invert(im))
    mn = Image.eval(im.split()[0], lambda v: v)  # placeholder
    px = im.load(); w, h = im.size
    m = Image.new('L', (w, h), 0); mp = m.load()
    for y in range(h):
        for x in range(w):
            r, g_, b = px[x, y]
            mp[x, y] = 255 if min(r, g_, b) < 228 or (max(r, g_, b) - min(r, g_, b)) > 28 else 0
    m = m.filter(ImageFilter.MedianFilter(5)).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(1.1))
    bbox = m.point(lambda v: 255 if v > 40 else 0).getbbox()
    rgba = im.convert('RGBA'); rgba.putalpha(m)
    return rgba.crop(bbox) if bbox else rgba

def frames(ref, k, offset=0, pick='compact'):
    key = (ref, k, offset, pick)
    if key in _cache: return _cache[key]
    r, fs = files(ref)
    n = 18
    cand = [fs[int(len(fs) * i / n)] for i in range(n)]
    subprocess.run(['git', '-C', REPO[r], 'checkout', 'HEAD', '--'] + cand, capture_output=True)
    scored = []
    for i, f in enumerate(cand):
        c = cutout(os.path.join(REPO[r], f))
        area = c.getchannel('A').point(lambda a: 255 if a > 128 else 0).histogram()[255]
        w, h = c.size
        # prefer big, not-too-thin, not touching full frame
        scored.append(((area * min(w, h) / max(w, h) ** 0.5) if pick == 'compact' else area * (w / max(h, 1)) if pick == 'wide' else area * (h / max(w, 1)), i, c))
    scored.sort(key=lambda t: -t[0])
    top = [s[2] for s in scored[:max(k + offset, k)]]
    res = top[offset:offset + k] if len(top) >= offset + k else top[:k]
    _cache[key] = res
    return res

def place(canvas, item, cx, cy, size, rot=0, shadow=True):
    it = item.rotate(rot, expand=True, resample=Image.BICUBIC) if rot else item
    w, h = it.size
    s = size / max(w, h)
    nw, nh = max(1, int(w * s)), max(1, int(h * s))
    it = it.resize((nw, nh), Image.LANCZOS)
    if s > 1.3:
        rgb = it.convert('RGB').filter(ImageFilter.UnsharpMask(radius=2, percent=70, threshold=2)); rgb.putalpha(it.getchannel('A')); it = rgb
    W = canvas.size[0]
    x, y = int(cx * W - nw / 2), int(cy * W - nh / 2)
    if shadow:
        sh = Image.new('RGBA', canvas.size, (0, 0, 0, 0)); d = ImageDraw.Draw(sh)
        d.ellipse([x + nw * .12, y + nh * .86, x + nw * .88, y + nh * 1.04], fill=(0, 0, 0, 60))
        sh = sh.filter(ImageFilter.GaussianBlur(W * .02))
        canvas.alpha_composite(sh)
    canvas.alpha_composite(it, (x, y))

LAYOUTS = {
    'single': [(.5, .52, .74, 0)],
    'duo': [(.38, .47, .58, -8), (.62, .55, .62, 6)],
    'trio': [(.31, .44, .50, -10), (.69, .44, .50, 10), (.5, .6, .58, 0)],
    'long3': [(.36, .5, .78, -24), (.5, .5, .8, 0), (.64, .52, .78, 22)],
    'bunch': [(.5, .4, .86, -6), (.5, .6, .86, 5)],
    'pile': [(.3, .38, .30, 0), (.5, .36, .30, 30), (.7, .38, .30, -20), (.2, .56, .30, 10), (.4, .56, .30, -15), (.6, .56, .30, 40),
             (.8, .56, .30, 0), (.32, .73, .30, 20), (.52, .74, .30, -30), (.71, .73, .30, 5)],
}

def render(spec, size=512, transparent=False, out=None):
    random.seed(out)
    canvas = Image.new('RGBA', (size, size), (255, 255, 255, 0 if transparent else 255))
    if spec['layout'] == 'mix':
        refs = spec['items']; n = len(refs)
        # arrange mixed items in two rows, back row first
        pos = {1: [(.5, .52, .7)], 2: [(.36, .5, .55), (.64, .54, .55)], 3: [(.3, .44, .48), (.7, .44, .48), (.5, .62, .52)],
               4: [(.3, .38, .44), (.7, .38, .44), (.32, .64, .46), (.68, .64, .46)],
               5: [(.25, .36, .40), (.5, .32, .40), (.75, .36, .40), (.36, .64, .44), (.64, .64, .44)],
               6: [(.22, .36, .38), (.5, .32, .38), (.78, .36, .38), (.24, .64, .40), (.5, .68, .40), (.76, .64, .40)]}[n]
        for ref, (cx, cy, s) in zip(refs, pos):
            rr, _, pk = ref.partition('@'); place(canvas, frames(rr, 1, 0, pk or 'compact')[0], cx, cy, s * size)
    else:
        lay = LAYOUTS[spec['layout']]
        fr = frames(spec['ref'], min(len(lay), 6), spec.get('offset', 0), spec.get('pick', 'compact'))
        for i, (cx, cy, s, rot) in enumerate(lay):
            place(canvas, fr[i % len(fr)], cx, cy, s * size * spec.get('scale', 1), rot)
    if transparent:
        canvas.save(out, optimize=True)
    else:
        canvas.convert('RGB').save(out, quality=84, optimize=True, progressive=True)

if __name__ == '__main__':
    import json
    specs = json.load(open(sys.argv[3]))
    only = set(sys.argv[4:])
    for name, spec in specs.items():
        if only and name not in only: continue
        tr = spec.get('transparent', False)
        render(spec, 320 if tr else 512, tr, os.path.join(OUT, name + ('.png' if tr else '.jpg')))
        print('ok', name, flush=True)
