## Generate/add an ssh key for the local machine
*This enables accessing github repos through `ssh`* (solves the `git@github.com: Permission denied (publickey)` problem, etc.)*.

*Directions written from [github ssh](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent)*

Check your GitHub ssh keys [here](https://github.com/settings/keys)

### 0. Install / login to GitHub CLI
```bash
sudo apt update && sudo apt install gh && gh auth login
```
TODO: try the "add ssh key" option when choosing ssh as preferred operating protocol

Add `ssh-key` to GitHub CLI
```
gh auth refresh -h github.com -s admin:public_key
```
### 1. Check entries for existing ssh keys in machine
```bash
ls -al ~/.ssh
```
Check for public ssh keys in output similar to:
```
id_rsa.pub
id_ecdsa.pub
id_ed25519.pub
```
**If a key exists, you can skip step 2**

### 2. If you don't have an ssh key, generate one
```
ssh-keygen -t ed25519 -C <your email>
```
Then:
```
> Enter a file in which to save the key (home)/.ssh/id_ALGORITHM):[Press enter]
```
(accept default location) (this will create `~/.ssh/id_ed25519`)

Then:
```
> Enter passphrase (empty for no passphrase): [Type a passphrase]
> Enter same passphrase again: [Type passphrase again]
```
(leave empty)


### 3. Add ssh key to `ssh-agent`

```bash
eval "$(ssh-agent -s)" && ssh-add ~/.ssh/id_ed25519
```

### 4. Add generated ssh key to the GitHub Account
```bash
gh ssh-key add ~/.ssh/id_ed25519.pub ---title "ssh_$(hostname)"
```
change title if needed

### 5. Check GitHub for added ssh key
Check your GitHub ssh keys [here](https://github.com/settings/keys)

### 6. Check ssh key validation
```
ssh git@github.com
```
Should print
```
PTY allocation request failed on channel 0
Hi iamchoking! You've successfully authenticated, but GitHub does not provide shell access.
Connection to github.com closed.
```