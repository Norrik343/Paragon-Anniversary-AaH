Paragon Anniversary - addon version
====================================

This is the client UI from Grim-Batol/Paragon-Anniversary (clientside/Interface),
repackaged as a normal 3.3.5a addon so no MPQ patch is needed.

INSTALL
  Copy the ParagonAnniversary folder into:
    World of Warcraft\Interface\AddOns\
  Enable "Paragon Anniversary" on the AddOns list at character select.
  Do NOT also install the original Patch-4.MPQ version; use one or the other.

USE
  Minimap button     Click to open/close. Drag to move it around the minimap.
                     A coin badge appears when you have unspent points.
  /paragon           Open/close the window
  /paragon preview   Fill the window with sample stats (client only, nothing is
                     sent or saved; /reload to exit)
  /paragon minimap   Show/hide the minimap button
  /paragon help      List commands
  Key binding        Game Menu > Key Bindings > "Paragon Anniversary"

WITHOUT THE SERVER SIDE
  The window opens but has no stats, because categories and stats come from the
  server. Use /paragon preview to see a filled-in layout.

CHANGES FROM THE ORIGINAL PATCH
  - Paragon, lib and Templates folders loaded through ParagonAnniversary.toc
    instead of a replacement FrameXML.toc
  - Custom textures moved to Textures\ and their paths updated
  - Modified Blizzard MainMenuBarMicroButtons files not included (no micro-menu
    button); replaced by the minimap button, /paragon and a key binding
  - lib\c_timer.lua not included (nothing used it, and it overwrote C_Timer)
  - Window can be dragged (the original never enabled dragging)
  - Layout: 6 stats per row (11px gap instead of 20) and 5 category rows
    (window 680px tall instead of 600)
  - Stats inside a category are sorted by stat ID, so the order follows
    paragon_config_statistic
  - /paragon preview shows the chosen 5-category, 20-stat layout
  - Window draws above action bars (HIGH strata)
