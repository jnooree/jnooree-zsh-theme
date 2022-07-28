# jnooree-zsh-theme

## Introduction

This is a minimal zsh theme with colors adopted from the [robbyrussell's theme](https://github.com/ohmyzsh/ohmyzsh/blob/master/themes/robbyrussell.zsh-theme). Displays current working directory and git information[^1] in the prompt.

[^1]: Implemented with zsh's `vsc_info` function.

If you're interested in this theme, then you might also want to check out my [zim](https://github.com/zimfw/zimfw) [configurations](https://github.com/jnooree/zim-cfg).

## Options

Several shell variables could control this theme's behavior:

- `DEFAULT_USER`: If `$USER` is same to `$DEFAULT_USER`, username would not appear in the rprompt; otherwise it will be displayed in this format: `${USER}@${SHORT_HOST}`. I've found this setting quite useful for whom might switch between multiple users (e.g., system admins). This must be set **before** sourcing the theme.
- `MIN_COLUMNS`: If the length of (shell expanded) current directory is greater than `$COLUMNS - $MIN_COLUMNS`, current working directory in the prompt will be truncated to the last two path components. If `$MIN_COLUMNS` is not set, it is default to `30`.

## Screenshots

### Default

<img width="673" alt="Screenshot of default profile" src="https://user-images.githubusercontent.com/63093572/181419771-5f3b4fbb-0393-4a64-8113-19ecac4978be.png">

### With git prompt

<img width="673" alt="Screenshot wit git prompt" src="https://user-images.githubusercontent.com/63093572/180684568-69621b8f-8d2a-43f2-aaa1-8fec479330c3.png">

### On ssh connection

<img width="673" alt="image" src="https://user-images.githubusercontent.com/63093572/181420247-f3959212-4306-48d6-9abd-4f7263c2b72c.png">

### Session of non-default user

<img width="673" alt="image" src="https://user-images.githubusercontent.com/63093572/181420354-e58ce9cb-75e3-435e-8c07-6bae117fd5f3.png">

## License and disclaimer

[The MIT License](LICENSE).
