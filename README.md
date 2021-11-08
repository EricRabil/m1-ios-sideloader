# m1-ios-sideloader
Sideload iOS apps regardless of security settings

## Notes
- Does not support encrypted IPAs at this time - you can grab decrypted IPAs with a simple google search or off of a jailbroken iDevice, or via [yacd](https://github.com/DerekSelander/yacd) on on iOS 13.4.1 and lower, no jb required

## Usage

```shell
install-ios-app ~/Downloads/Instagram.ipa /Applications/Instagram.app
```

```shell
# Alternative patching method if default isn't working well
install-ios-app --vtool ~/Downloads/Instagram.ipa /Applications/Instagram.app
```
