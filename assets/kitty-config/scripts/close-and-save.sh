#!/bin/bash
# Browser-style Cmd+W: capture full state + save to stack, then close tab

# 1. Capture kitty state
export KITTY_SAVE_DATA
KITTY_SAVE_DATA=$(kitten @ ls 2>/dev/null)
if [[ -z "$KITTY_SAVE_DATA" ]]; then
    kitten @ close-tab --self
    exit 0
fi

# 2. Capture state + write to stack + output target pane ID (all in one script)
TARGET=$(python3 << 'PYEOF'
import json, subprocess, sys, os, time

STACK_FILE = os.path.expanduser("~/.config/kitty/sessions/recently-closed.json")
MAX_STACK = 20

data = json.loads(os.environ['KITTY_SAVE_DATA'])

my_os_win = None
my_tab = None
for o in data:
    if o.get('is_focused'):
        my_os_win = o
        for t in o.get('tabs', []):
            if t.get('is_focused') or t.get('is_active'):
                my_tab = t
                break
        break

if not my_os_win or not my_tab:
    sys.exit(1)

num_tabs = len(my_os_win.get('tabs', []))
is_last_tab = num_tabs <= 1
platform_window_id = my_os_win.get('platform_window_id')

# Get window position only if last tab
position = None
if is_last_tab and platform_window_id:
    try:
        swift_code = (
            'import CoreGraphics\n'
            'let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []\n'
            'for w in windowList {\n'
            '    guard let owner = w["kCGWindowOwnerName"] as? String,\n'
            '          owner == "kitty",\n'
            '          let wid = w["kCGWindowNumber"] as? Int,\n'
            '          wid == ' + str(platform_window_id) + ',\n'
            '          let bounds = w["kCGWindowBounds"] as? [String: Any],\n'
            '          let x = bounds["X"] as? Double,\n'
            '          let y = bounds["Y"] as? Double,\n'
            '          let width = bounds["Width"] as? Double,\n'
            '          let height = bounds["Height"] as? Double\n'
            '    else { continue }\n'
            '    print("\\(Int(x)),\\(Int(y)),\\(Int(width)),\\(Int(height))")\n'
            '}\n'
        )
        result = subprocess.run(['swift', '-e', swift_code], capture_output=True, text=True, timeout=10)
        parts = result.stdout.strip().split(',')
        if len(parts) == 4:
            position = [int(p) for p in parts]
    except:
        pass

panes_data = []
target_pane_id = None

for win in my_tab.get('windows', []):
    if win.get('is_self'):
        continue

    if target_pane_id is None:
        target_pane_id = win['id']

    # Capture colors
    colors = {}
    try:
        colors_raw = subprocess.check_output(
            ['kitten', '@', 'get-colors', '--match', 'id:' + str(win['id'])]
        ).decode().strip()
        for line in colors_raw.split('\n'):
            parts = line.strip().split()
            if len(parts) >= 2:
                colors[parts[0]] = parts[1]
    except:
        pass

    # Get real CWD via lsof
    fg_procs = win.get('foreground_processes', [])
    real_cwd = win.get('cwd', '')

    for proc in fg_procs:
        cmd = ' '.join(proc.get('cmdline', []))
        if '/bin/claude' in cmd:
            pid = proc.get('pid')
            if pid:
                try:
                    ps_r = subprocess.run(['ps', '-o', 'ppid=', '-p', str(pid)],
                                         capture_output=True, text=True, timeout=3)
                    shell_pid = ps_r.stdout.strip()
                    if shell_pid:
                        lsof_r = subprocess.run(['lsof', '-a', '-p', shell_pid, '-d', 'cwd', '-Fn'],
                                               capture_output=True, text=True, timeout=3)
                        for line in lsof_r.stdout.split('\n'):
                            if line.startswith('n/'):
                                real_cwd = line[1:]
                                break
                except:
                    pass
            break
    else:
        for proc in fg_procs:
            pid = proc.get('pid')
            if pid:
                try:
                    lsof_r = subprocess.run(['lsof', '-a', '-p', str(pid), '-d', 'cwd', '-Fn'],
                                           capture_output=True, text=True, timeout=3)
                    for line in lsof_r.stdout.split('\n'):
                        if line.startswith('n/'):
                            real_cwd = line[1:]
                            break
                except:
                    pass
                break

    # Detect Claude session
    claude_session = None
    has_claude = False
    claude_pid = None
    for proc in fg_procs:
        cmd = ' '.join(proc.get('cmdline', []))
        if 'claude' in cmd.lower() and '/bin/claude' in cmd:
            has_claude = True
            claude_pid = proc.get('pid')
            args = proc.get('cmdline', [])
            for i, arg in enumerate(args):
                if arg in ('--resume', '-r') and i + 1 < len(args):
                    claude_session = args[i + 1]
                    break
            break

    user_vars = win.get('user_vars', {})
    panes_data.append({
        'cwd': real_cwd,
        'colors': colors,
        'claude_session': claude_session,
        'has_claude': has_claude,
        'user_vars': user_vars,
        '_claude_pid': claude_pid
    })

# Match PIDs to sessions
from collections import defaultdict
cwd_panes = defaultdict(list)
for pane in panes_data:
    pid = pane.pop('_claude_pid', None)
    if pid and not pane.get('claude_session'):
        cwd_panes[pane['cwd']].append((pane, pid))

for cwd, pane_list in cwd_panes.items():
    try:
        slug = cwd.replace('/', '-').replace(' ', '-')
        proj_dir = os.path.join(os.path.expanduser('~/.claude/projects'), slug)
        if not os.path.isdir(proj_dir):
            continue
        already_assigned = set()
        for p in panes_data:
            if p['cwd'] == cwd and p.get('claude_session'):
                already_assigned.add(p['claude_session'])
        jsonl_files = [f for f in os.listdir(proj_dir) if f.endswith('.jsonl')]
        jsonl_files.sort(key=lambda f: os.path.getmtime(os.path.join(proj_dir, f)), reverse=True)
        available = [f.replace('.jsonl', '') for f in jsonl_files if f.replace('.jsonl', '') not in already_assigned]
        pane_list.sort(key=lambda x: x[1] or 0, reverse=True)
        for i, (pane_ref, pid) in enumerate(pane_list):
            if i < len(available):
                pane_ref['claude_session'] = available[i]
    except:
        pass

# Write to stack file
if panes_data:
    entry = {
        'timestamp': time.time(),
        'is_last_tab': is_last_tab,
        'platform_window_id': platform_window_id,
        'position': position,
        'tab_title': my_tab.get('title', ''),
        'panes': panes_data
    }

    stack = []
    if os.path.isfile(STACK_FILE):
        try:
            with open(STACK_FILE) as f:
                stack = json.load(f)
        except:
            stack = []

    stack.append(entry)
    stack = stack[-MAX_STACK:]
    os.makedirs(os.path.dirname(STACK_FILE), exist_ok=True)
    with open(STACK_FILE, 'w') as f:
        json.dump(stack, f, indent=2)

# Output target pane ID for bash to close
if target_pane_id:
    print(target_pane_id)
PYEOF
)

# 3. Close the tab (--self = close the tab this overlay is running in, scoped to this OS window)
kitten @ close-tab --self
