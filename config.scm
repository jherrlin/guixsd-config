;; This is an operating system configuration template
;; for a "desktop" setup without full-blown desktop
;; environments.

(use-modules
 (srfi srfi-1)
 (srfi srfi-9)
 (ice-9 rdelim)
 (gnu)
 (gnu system nss)
 (gnu system locale)
 (gnu packages emacs)
 (gnu packages xdisorg)
 (gnu packages guile)
 (gnu packages networking)
 (gnu packages ntp)
 (gnu packages libusb)
 (gnu services)
 (gnu services networking)
 (gnu services xorg)
 (gnu services web)
 (gnu services desktop)
 )


(define xkeyboard-config "
Section \"InputClass\"
     Identifier \"keyboard-all\" \"system-keyboard\"
     MatchIsKeyboard \"on\"
     MatchDevicePath \"/dev/input/event*\"
     Driver \"evdev\"
     Option \"XkbModel\" \"pc105\"
     Option \"XkbLayout\" \"us,se\"
     Option \"XkbVariant\" \",\"
     Option \"XkbOptions\" \"grp:win_space_toggle,caps:ctrl_modifier\"
     MatchIsKeyboard \"on\"
EndSection
")


(use-service-modules dbus networking desktop)
(use-package-modules bootloaders wm ratpoison certs suckless emacs)

(operating-system
  (host-name "antelope")
  (timezone "Europe/Stockholm")
  (locale "en_US.utf8")
  (locale-definitions
   (list
    (locale-definition (name "en_US.utf8") (source "en_US") (charset "UTF-8"))
    (locale-definition (name "sv_SE.utf8") (source "sv_SE") (charset "UTF-8"))))

  ;; Assuming /dev/sdX is the target hard disk, and "my-root"
  ;; is the label of the target root file system.
  ;;
  ;; Device       Start       End   Sectors   Size Type
  ;; /dev/sda1     2048   1026047   1024000   500M EFI System
  ;; /dev/sda2  1026048   9414655   8388608     4G Linux swap
  ;; /dev/sda3  9414656 234441614 225026959 107.3G Linux filesystem
  ;;
  (bootloader (bootloader-configuration
	       (bootloader grub-efi-bootloader)
	       (target "/boot/efi")))

  (file-systems (cons* (file-system
			 (device "guixsd-root")
			 (title 'label)
			 (mount-point "/")
			 (type "ext4"))
		       (file-system
			 (device "/dev/sda1")
			 (mount-point "/boot")
			 (needed-for-boot? #t)
			 (type "vfat"))
		       %base-file-systems))
  (swap-devices '("/dev/sda2"))

  (kernel-arguments '("modprobe.blacklist=pcspkr,snd_pcsp"))

  (users (cons (user-account
		(name "nils")
		(comment "user")
		(group "users")
		(supplementary-groups '("wheel" "netdev"
					"audio" "video"))
		(home-directory "/home/nils"))
	       %base-user-accounts))

  ;; Add a bunch of window managers; we can choose one at
  ;; the log-in screen with F1.
  (packages (cons* ratpoison i3-wm i3status dmenu ;window managers
		   nss-certs                      ;for HTTPS access
		   emacs
		   emacs-guix
		   rxvt-unicode
		   ;; git
		   %base-packages))

  (services
   (cons*
    ;; https://lists.gnu.org/archive/html/help-guix/2016-05/msg00042.html
    (slim-service
     #:allow-empty-passwords? #f #:auto-login? #f
     #:startx (xorg-start-command
	       #:configuration-file
	       (xorg-configuration-file
		#:extra-config (list xkeyboard-config))))
    ;; https://git.savannah.gnu.org/cgit/guix.git/tree/gnu/services/desktop.scm?id=v0.13.0-2323-g35131babc#n799
    ;;
    ;; Screen lockers are a pretty useful thing and these are small.
    (screen-locker-service slock)
    (screen-locker-service xlockmore "xlock")

    ;; Add udev rules for MTP devices so that non-root users can access
    ;; them.
    (simple-service 'mtp udev-service-type (list libmtp))

    ;; The D-Bus clique.
    (udisks-service)
    (upower-service)
    (accountsservice-service)
    (colord-service)
    (geoclue-service)
    (polkit-service)
    (elogind-service)
    (dbus-service)

    ;; https://www.gnu.org/software/guix/manual/guix.html#Networking-Services
    (dhcp-client-service)
    (ntp-service #:allow-large-adjustment? #t)

    %base-services))


  ;; Allow resolution of '.local' host names with mDNS.
  (name-service-switch %mdns-host-lookup-nss))
