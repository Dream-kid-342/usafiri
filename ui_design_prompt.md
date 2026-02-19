# UI/UX Design Prompt: Premium App Permission Manager

## Project Overview
Build a modern, minimalistic Android app UI for an app permission manager with M-Pesa subscription integration. The app should feel premium, clean, and effortless to use, drawing inspiration from Spotify and Duolingo's design philosophy.

---

## Design Philosophy & Principles

### Core Values
1. **Effortless Simplicity** - Every interaction should feel natural and require minimal cognitive load
2. **Premium Feel** - Users should feel they're using a high-quality, professional product
3. **Delightful Interactions** - Micro-animations and smooth transitions that make the app enjoyable
4. **Trust & Security** - Visual design that communicates safety, especially for payment flows
5. **Speed Perception** - Fast loading states and instant feedback

### Design Inspirations

**From Spotify:**
- Bold use of dark themes with vibrant accent colors
- Card-based layouts with subtle shadows and depth
- Smooth, fluid animations and transitions
- Clear visual hierarchy with generous whitespace
- Premium typography with bold headers
- Bottom sheet modals for actions
- Skeleton loading states

**From Duolingo:**
- Playful yet professional tone
- Clear progress indicators and streaks
- Encouraging feedback and celebrations (confetti animations)
- Bright, friendly color palette
- Large, tappable buttons with rounded corners
- Gamification elements (trial countdown as progress)
- Character and personality in empty states

---

## Visual Design System

### Color Palette

**Primary Colors:**
```
Primary Blue: #2563EB (trust, security, professionalism)
  - Light variant: #60A5FA
  - Dark variant: #1E40AF

M-Pesa Green: #00A651 (payment, success, go)
  - Light variant: #4ADE80
  - Dark variant: #16A34A
```

**Neutral Colors:**
```
Background (Light): #FFFFFF
Background (Dark): #0F0F0F
Surface (Light): #F8FAFC
Surface (Dark): #1A1A1A
Card (Light): #FFFFFF
Card (Dark): #262626

Text Primary (Light): #0F172A
Text Primary (Dark): #F8FAFC
Text Secondary (Light): #64748B
Text Secondary (Dark): #94A3B8
```

**Semantic Colors:**
```
Success: #22C55E
Warning: #F59E0B
Error: #EF4444
Info: #3B82F6
```

**Gradient Accents:**
```
Hero Gradient: Linear gradient from #2563EB to #7C3AED (45deg)
Success Gradient: Linear gradient from #10B981 to #06B6D4 (135deg)
Card Shimmer: Linear gradient with white/transparent for loading states
```

### Typography

**Font Family:**
- Primary: **Inter** or **SF Pro Display** (clean, modern, highly legible)
- Numbers: **JetBrains Mono** for transaction amounts (monospaced clarity)

**Type Scale:**
```
Display Large: 57sp / Bold / -0.25sp letter spacing
Display Medium: 45sp / Bold / 0sp letter spacing
Display Small: 36sp / Bold / 0sp letter spacing

Headline Large: 32sp / Bold / 0sp letter spacing
Headline Medium: 28sp / Bold / 0sp letter spacing
Headline Small: 24sp / Bold / 0sp letter spacing

Title Large: 22sp / SemiBold / 0sp letter spacing
Title Medium: 16sp / SemiBold / 0.15sp letter spacing
Title Small: 14sp / SemiBold / 0.1sp letter spacing

Body Large: 16sp / Regular / 0.5sp letter spacing
Body Medium: 14sp / Regular / 0.25sp letter spacing
Body Small: 12sp / Regular / 0.4sp letter spacing

Label Large: 14sp / Medium / 0.1sp letter spacing
Label Medium: 12sp / Medium / 0.5sp letter spacing
Label Small: 11sp / Medium / 0.5sp letter spacing
```

### Spacing System
Use 4dp base unit for consistent spacing:
```
4dp, 8dp, 12dp, 16dp, 24dp, 32dp, 48dp, 64dp, 96dp
```

**Common Patterns:**
- Screen padding: 16dp horizontal, 12dp vertical
- Card padding: 16dp
- Element spacing: 12dp
- Section spacing: 24dp
- Screen margins: 16dp

### Elevation & Shadows

**Material 3 Elevation Levels:**
```
Level 0: No shadow (flat surface)
Level 1: 0dp 1dp 3dp rgba(0,0,0,0.12), 0dp 1dp 2dp rgba(0,0,0,0.24)
Level 2: 0dp 3dp 6dp rgba(0,0,0,0.15), 0dp 2dp 4dp rgba(0,0,0,0.12)
Level 3: 0dp 10dp 20dp rgba(0,0,0,0.15), 0dp 3dp 6dp rgba(0,0,0,0.10)
Level 4: 0dp 15dp 25dp rgba(0,0,0,0.15), 0dp 5dp 10dp rgba(0,0,0,0.05)
Level 5: 0dp 20dp 40dp rgba(0,0,0,0.20)
```

**Usage:**
- Floating cards: Level 1
- Raised buttons: Level 2
- Modals/Bottom sheets: Level 4
- Dialogs: Level 5

### Border Radius
```
Small: 8dp (chips, small buttons)
Medium: 12dp (cards, inputs)
Large: 16dp (prominent cards, containers)
Extra Large: 24dp (bottom sheets, modals)
Full: 999dp (circular buttons, avatars)
```

### Icons
- **Icon Set:** Material Symbols (Rounded variant)
- **Size:** 24dp standard, 20dp small, 32dp large
- **Weight:** 300 (light and modern)
- **Style:** Rounded edges for friendliness

---

## Screen-by-Screen Design Specifications

### 1. Splash Screen

**Layout:**
```
[Centered vertically and horizontally]
- App Icon (120dp x 120dp) with subtle pulse animation
- App Name (32sp, Bold) below icon with 16dp margin
- Tagline "Manage permissions, simply." (14sp, Regular, 60% opacity)
- Loading indicator (small, beneath tagline, 24dp margin)
```

**Animations:**
- Icon: Scale from 0.8 to 1.0 with overshoot (duration: 600ms)
- Text: Fade in after icon (delay: 200ms, duration: 400ms)
- Auto-dismiss after 1.5 seconds or when app ready

**Color:**
- Background: Gradient from Primary Blue to Purple (#7C3AED)
- Icon/Text: White
- Loading indicator: White with 70% opacity

---

### 2. Onboarding Screens (3 screens)

**General Layout:**
```
[Full screen, vertical layout]

Top Section (60% of screen):
  - Large illustration/animation (SVG, Lottie)
  - Clean, minimalist graphics
  
Bottom Section (40% of screen):
  - Headline (28sp, Bold, Primary Text)
  - Body text (16sp, Regular, Secondary Text, max 2 lines)
  - Progress dots (8dp each, 8dp spacing)
  - Primary CTA button (full width - 32dp margin)
  - Skip button (top right, text button, 12sp)
```

**Screen 1: Welcome**
- **Illustration:** Shield with checkmark (protection theme)
- **Headline:** "Take Control of Your Privacy"
- **Body:** "Manage which apps can access your location, all in one place."
- **CTA:** "Continue"

**Screen 2: Features**
- **Illustration:** Toggle switches with app icons
- **Headline:** "One Tap to Control Access"
- **Body:** "Toggle location permissions for any app instantly. No more diving into settings."
- **CTA:** "Next"

**Screen 3: Trial**
- **Illustration:** Calendar with checkmark
- **Headline:** "Try Free for 7 Days"
- **Body:** "Full access to all features. Only KES 199/month after trial."
- **CTA:** "Start Free Trial"

**Design Details:**
- Progress dots: Active dot is Primary Blue (12dp), inactive dots are gray (8dp)
- Button: 48dp height, 16dp corner radius, Primary Blue background
- Skip button: Small, subtle, top-right (16dp margin)
- Smooth horizontal swipe transition between screens

---

### 3. Permission Request Screen

**Layout:**
```
[Centered content with illustration]

- Large illustration of phone with settings icon (200dp height)
- Headline: "We Need Your Permission" (24sp, Bold)
- Body text explaining why (14sp, Regular, 24dp margin)
- Permission list (each with icon + description)
- Primary button: "Grant Permission"
- Secondary button: "Why is this needed?" (text button)
```

**Permission Cards:**
```
[Horizontal layout, 12dp vertical spacing]
- Icon (24dp, Primary Blue tint)
- Text Column:
  - Title (14sp, SemiBold)
  - Description (12sp, Regular, Secondary color)
- Checkmark icon when granted (16dp, Success Green)
```

**Animations:**
- Cards slide in from bottom, staggered (100ms delay each)
- Checkmark appears with scale + bounce when permission granted

---

### 4. Phone Number Entry Screen

**Layout:**
```
[Vertical centered layout]

Header:
  - Back button (top left)
  - Progress indicator: "Step 1 of 2" (top right, 12sp)

Content (centered):
  - Icon: Phone with M-Pesa logo (64dp)
  - Headline: "Enter Your M-Pesa Number" (24sp, Bold)
  - Subtext: "We'll send you a verification code" (14sp, Regular, Secondary)
  
Input Section (24dp top margin):
  - Country code prefix: "+254" (non-editable, 16sp, in input)
  - Phone number input field (56dp height, 16dp padding)
    - Placeholder: "712 345 678"
    - Input type: Phone number keyboard
  - Helper text: "Must be registered with M-Pesa" (12sp, below input)
  
Bottom Section:
  - Primary button: "Continue" (disabled until valid input)
  - Terms text: "By continuing, you agree to our Terms & Privacy Policy" (11sp, links underlined)
```

**Input Field Design:**
- Border: 1dp, neutral color (default)
- Border: 2dp, Primary Blue (focused)
- Border: 2dp, Error Red (error state)
- Corner radius: 12dp
- Background: Surface color
- Icon: Phone icon left side (20dp)
- Clear button: X icon right side (appears when typing)

**Validation:**
- Real-time validation as user types
- Green checkmark appears when valid
- Error message below field if invalid
- Button enabled only when valid

---

### 5. OTP Verification Screen

**Layout:**
```
[Vertical centered layout]

Header:
  - Back button (top left)
  - Progress indicator: "Step 2 of 2" (top right)

Content:
  - Icon: Envelope with code (64dp)
  - Headline: "Verify Your Number" (24sp, Bold)
  - Subtext: "Code sent to +254 712 345 678" (14sp, edit link)
  
OTP Input Section:
  - 6 boxes for OTP digits (48dp x 56dp each)
  - Auto-focus on first box
  - Auto-advance as user types
  - Large digits (24sp, Monospace)
  
Timer Section (16dp below OTP):
  - Text: "Code expires in 4:32" (12sp, Error color if <1 min)
  
Resend Section:
  - Text: "Didn't receive code?" (14sp)
  - Link: "Resend Code" (14sp, Primary Blue, disabled for 60s)
  
Bottom:
  - Primary button: "Verify" (auto-enabled when 6 digits entered)
```

**OTP Box Design:**
- Border: 2dp, Neutral color (empty)
- Border: 2dp, Primary Blue (focused/filled)
- Border: 2dp, Success Green (all filled, correct)
- Border: 2dp, Error Red (wrong code)
- Background: Surface color
- Corner radius: 12dp
- Spacing: 8dp between boxes

**Animations:**
- Shake animation if wrong code
- Success checkmark animation when verified
- Boxes pulse slightly when focused

---

### 6. Trial Started Screen (Success)

**Layout:**
```
[Full screen, centered content]

Top Half:
  - Lottie animation: Confetti falling (2 seconds loop)
  - Success icon: Large checkmark in circle (120dp, Success Green)
  
Middle:
  - Headline: "You're All Set!" (32sp, Bold)
  - Subtext: "Your 7-day free trial has started" (16sp, Regular)
  
Trial Info Card:
  - White/Surface background
  - 16dp padding, 16dp corner radius
  - Elevation: Level 2
  - Content:
    - "Trial ends:" label (12sp, Secondary color)
    - Date (18sp, Bold, Primary color)
    - "You won't be charged until then" (12sp, Secondary)
  
Bottom:
  - Primary button: "Start Managing Permissions" (full width)
  - Small text: "You can cancel anytime" (11sp, center, Secondary)
```

**Animations:**
- Confetti falls from top (celebration)
- Checkmark draws in with stroke animation
- Card slides up with bounce
- Button fades in last

---

### 7. Main Screen (App List)

This is the core screen and should be exceptionally polished.

**Layout:**
```
[Full screen with header, list, and FAB]

Header (Fixed):
  - App logo/name (left, 20sp, Bold)
  - Search icon (right)
  - Filter icon (right of search)
  
Trial/Subscription Banner (Collapsible):
  - Gradient background (Primary Blue to Purple)
  - Left side: 
    - "X days left in trial" (16sp, Bold, White)
    - "Subscribe to continue access" (12sp, Regular, White 80%)
  - Right side:
    - "Subscribe" button (compact, white background, blue text)
  - Dismiss X (top right corner)
  - Height: 72dp
  - Padding: 16dp
  - Corner radius: 0dp (top), 16dp (bottom)
  
App List:
  - RecyclerView with smooth scrolling
  - Each item is a card with app info
  - Swipe actions (optional)
  
Floating Action Button (FAB):
  - Bottom right (16dp margin)
  - Icon: Settings or subscription icon
  - Background: Primary Blue
  - Size: 56dp
  - Elevation: Level 3
  - Label: "Subscription" (appears on long press)
```

**App List Item Design:**
```
[Card, full width - 16dp margins, 12dp vertical spacing]

Layout: Horizontal
- App Icon (48dp, rounded 12dp)
- Text Column (flex, 12dp left margin):
  - App Name (16sp, SemiBold, Primary text)
  - Package name (12sp, Regular, Secondary text, ellipsize)
  - Last accessed (11sp, Regular, Secondary text)
    - "Active now" (Success Green)
    - "2 hours ago" (Secondary)
    - "Never" (Disabled color)
- Toggle Switch (right, 16dp margin)
  - Active (Primary Blue track, white thumb)
  - Inactive (Gray track and thumb)
  - Smooth 200ms toggle animation
  
Card Properties:
- Background: Surface color
- Elevation: Level 1
- Corner radius: 12dp
- Padding: 12dp
- Ripple effect on tap (except switch)
```

**List States:**

1. **Loading State:**
   - Shimmer effect on cards
   - Skeleton loaders for app icon, text, toggle
   - 8 skeleton cards visible

2. **Empty State:**
   - Large illustration (no apps found)
   - Headline: "No Apps Found" (20sp, Bold)
   - Subtext: "Try adjusting your filters" (14sp, Regular)
   - Button: "Clear Filters"

3. **Error State:**
   - Error icon with message
   - Retry button

**Filter Bottom Sheet:**
- Appears from bottom when filter icon tapped
- Semi-transparent backdrop (60% black)
- White/Surface background
- 24dp top corner radius
- Sections:
  1. Sort By: Alphabetical, Recent, Permission Status
  2. Show: All Apps, System Apps, User Apps Only
  3. Permission: All, Granted, Denied
- Apply button (Primary, full width)
- Reset link (top right)

---

### 8. App Details Screen

**Layout:**
```
[Scrollable with header]

Header (Image):
  - Blurred app icon background (full width, 200dp height)
  - App icon centered (96dp, rounded 24dp, elevated)
  - Back button (top left, white, with backdrop)
  
Content:
  - App Name (24sp, Bold, centered)
  - Package name (12sp, Monospace, Secondary, centered)
  - Install date (12sp, Regular, Secondary, centered)
  
Permission Section:
  - Section header: "Location Permission" (16sp, SemiBold)
  - Current status card:
    - Large toggle (center)
    - Status text: "Allowed" or "Denied" (18sp, Bold)
    - Description text
    - Last accessed timestamp
  
All Permissions Section (Expandable):
  - Header: "All Permissions" (16sp, SemiBold)
  - Collapse/expand icon
  - List of permissions (read-only):
    - Icon + Name + Status badge
  
Action Buttons:
  - "Open App Settings" (secondary button)
  - "Uninstall App" (text button, error color)
```

---

### 9. Payment Screen

**This is CRITICAL - must feel secure and trustworthy**

**Layout:**
```
[Centered, minimal distractions]

Header:
  - Close button (top left, X)
  - "Subscription" title (16sp, SemiBold, centered)
  
Hero Section:
  - M-Pesa logo (64dp, official colors)
  - Headline: "Subscribe to Continue" (24sp, Bold)
  - Subtext: "Unlock full access to all features" (14sp, Regular)
  
Pricing Card:
  - Large, centered, elevated (Level 3)
  - Background: White (light) or Dark surface (dark)
  - Border: 2dp, Success Green (subtle glow)
  - Corner radius: 20dp
  - Padding: 24dp
  - Content:
    - "Monthly Subscription" (12sp, SemiBold, Secondary)
    - Amount: "KES 199" (48sp, Bold, Primary, Monospace)
    - Per period: "/month" (14sp, Regular, Secondary)
    - Features list (checkmarks):
      - "Manage unlimited apps" (14sp)
      - "One-tap permission control" (14sp)
      - "Priority support" (14sp)
    - Billed monthly text (11sp, Secondary)
  
Phone Number Section:
  - Label: "M-Pesa Number" (12sp, SemiBold)
  - Input: "+254 712 345 678" (pre-filled, editable)
  - Edit icon (right side)
  - Verification badge if verified (checkmark)
  
Legal Section:
  - Checkbox: "I agree to auto-renewal" (12sp)
  - Links: "Terms of Service" and "Privacy Policy"
  - Small text: "Cancel anytime" (11sp, Secondary)
  
CTA Button:
  - "Pay with M-Pesa" (full width, 56dp height)
  - M-Pesa logo + text
  - Background: M-Pesa Green
  - Text: White
  - Large corner radius: 16dp
  - Prominent shadow
  
Security Badge:
  - Lock icon + "Secure payment" (11sp, centered, Secondary)
```

**Payment Processing State:**
```
[Same layout, overlay modal]

Modal (centered):
  - Background: Surface with blur backdrop
  - Corner radius: 24dp
  - Padding: 32dp
  - Elevation: Level 5
  - Content:
    - Animated M-Pesa logo (pulse)
    - "Waiting for payment..." (18sp, SemiBold)
    - "Please enter your M-Pesa PIN" (14sp, Regular, Secondary)
    - Loading spinner (M-Pesa Green)
    - Timer: "Expires in 00:48" (12sp, Error color if <20s)
    - "Cancel Payment" button (text, small)
```

**Payment Success State:**
```
[Full screen celebration]

- Lottie animation: Confetti + success checkmark
- Large checkmark (120dp, Success Green)
- Headline: "Payment Successful!" (28sp, Bold)
- Subtext: "Your subscription is now active" (14sp, Regular)
- Receipt card:
  - Transaction ID
  - Amount paid
  - Date/Time
  - "Download Receipt" link
- Primary button: "Continue" (goes to main screen)
```

**Payment Failed State:**
```
[Same modal layout]

- Error icon (64dp, Error Red)
- Headline: "Payment Failed" (20sp, Bold)
- Reason: Specific error message (14sp, Regular)
  - Examples:
    - "Payment was cancelled"
    - "Insufficient M-Pesa balance"
    - "Wrong PIN entered"
- Primary button: "Try Again"
- Secondary button: "Contact Support"
```

---

### 10. Subscription Management Screen

**Layout:**
```
[Scrollable content]

Header:
  - Back button (top left)
  - "Subscription" title (16sp, SemiBold, centered)
  - Settings icon (top right)
  
Status Card (Top):
  - Background: Gradient (Success Green if active, Gray if expired)
  - Padding: 24dp
  - Corner radius: 16dp
  - Elevation: Level 2
  - Content:
    - Status badge: "Active" or "Expired" (12sp, pill shape)
    - Headline: "Premium Member" (24sp, Bold, White)
    - Subtext: "Since March 2024" (12sp, Regular, White 80%)
    - Renewal date: "Next billing: Apr 10, 2026" (14sp, SemiBold)
  
Payment Details Section:
  - Section header: "Payment Method" (14sp, SemiBold)
  - Card:
    - M-Pesa logo
    - Phone number (masked): "+254 712 *** 678"
    - "Change" link (right side)
  
Billing History Section:
  - Section header: "Billing History" (14sp, SemiBold)
  - List items:
    - Date (left, 14sp, SemiBold)
    - Amount (right, 14sp, Bold, Monospace)
    - Status badge: "Paid", "Failed", "Pending"
    - Receipt icon (download)
  - "View All" link at bottom
  
Actions Section:
  - "Cancel Subscription" button (secondary, error color)
  - Warning text: "Your access will continue until X date"
```

---

### 11. Settings Screen

**Layout:**
```
[Grouped list with sections]

Header:
  - Back button (top left)
  - "Settings" title (16sp, SemiBold, centered)
  
Account Section:
  - Section header: "Account" (12sp, SemiBold, Secondary, uppercase)
  - Items:
    - Profile (icon + "Your Account" + chevron)
    - Phone number (icon + number + verified badge)
  
Preferences Section:
  - Section header: "Preferences"
  - Items:
    - Theme (icon + "Appearance" + "Dark" label + chevron)
    - Language (icon + "Language" + "English" label)
    - Notifications (icon + "Notifications" + toggle switch)
    - Show system apps (icon + label + toggle)
  
Support Section:
  - Section header: "Support"
  - Items:
    - Help Center (icon + label + external link icon)
    - Contact Support (icon + WhatsApp/Email)
    - FAQ (icon + label + chevron)
  
Legal Section:
  - Section header: "Legal"
  - Items:
    - Terms of Service (icon + label + external link)
    - Privacy Policy (icon + label + external link)
    - Licenses (icon + label + chevron)
  
Danger Zone:
  - "Delete Account" (text button, error color)
  - Small warning text below
  
App Info:
  - Version number (11sp, center, Secondary)
  - "Made with ❤️ in Kenya" (11sp, center, Secondary)
```

**List Item Design:**
```
[Horizontal layout, 56dp min height]

- Icon (24dp, left, 16dp margin, Primary Blue tint)
- Text Column (flex):
  - Label (14sp, SemiBold, Primary text)
  - Sublabel (12sp, Regular, Secondary text) [optional]
- Right Element:
  - Chevron (16dp, Secondary color) OR
  - Toggle switch OR
  - Badge/Label (12sp, pill shape)
- Ripple on tap
- Divider (1dp, 56dp left inset)
```

---

## Interaction & Animation Patterns

### Micro-interactions

1. **Button Press:**
   - Scale down to 0.96 (100ms)
   - Scale back to 1.0 with slight overshoot (200ms)
   - Ripple effect from tap point

2. **Toggle Switch:**
   - Thumb slides with ease-out curve (200ms)
   - Track color crossfades (200ms)
   - Haptic feedback on toggle

3. **Card Tap:**
   - Ripple from tap point
   - Subtle scale (1.0 to 0.98 to 1.0)
   - Navigate with shared element transition

4. **Pull to Refresh:**
   - Custom loader matching app style
   - Rotate + scale animation
   - Haptic feedback when threshold reached

5. **Successful Action:**
   - Green checkmark draws in
   - Scale from 0 to 1.2 to 1.0 (bounce)
   - Optional confetti for major actions

### Screen Transitions

1. **Standard Navigation:**
   - Slide from right (enter)
   - Fade out slightly (exit)
   - Duration: 300ms
   - Curve: Ease-out

2. **Bottom Sheet:**
   - Slide up from bottom
   - Fade in backdrop (60% black)
   - Duration: 250ms
   - Curve: Ease-out
   - Dismiss: Swipe down or tap backdrop

3. **Dialog/Modal:**
   - Scale from 0.9 to 1.0
   - Fade in backdrop
   - Duration: 200ms
   - Curve: Ease-out

4. **Shared Element:**
   - App icon → App details
   - Smooth morph transition
   - Duration: 350ms

### Loading States

1. **Shimmer Effect:**
   - Light gray base
   - White shimmer sweeps left to right
   - Duration: 1500ms
   - Loop indefinitely

2. **Skeleton Screens:**
   - Use for app list, payment history
   - Match actual content layout
   - Rounded rectangles for text
   - Circles for icons

3. **Progress Indicators:**
   - Circular: Primary Blue, 48dp
   - Linear: Top of screen, 4dp height
   - Determinate when possible

### Haptic Feedback

Use subtle haptics for:
- Toggle switches
- Button taps (light impact)
- Pull to refresh threshold
- Successful actions (notification feedback)
- Errors (error feedback)
- Payment completion (success feedback)

---

## Accessibility Requirements

### Visual Accessibility
- Minimum contrast ratio: 4.5:1 for text
- Touch targets: Minimum 48dp x 48dp
- Scalable text up to 200%
- Support system font size preferences
- Color is not the only indicator (use icons too)

### Screen Reader Support
- All interactive elements have content descriptions
- Headings properly marked
- Announce state changes ("Permission granted")
- Reading order is logical

### Motion Accessibility
- Respect "Reduce motion" system setting
- Provide static alternatives to animations
- Ensure app is usable without animations

### Keyboard Navigation
- Support for external keyboards
- Clear focus indicators
- Logical tab order

---

## Dark Mode Specifications

### Color Adjustments
```
Background: #0F0F0F (pure black strains eyes, slightly lighter)
Surface: #1A1A1A
Card: #262626
Elevated Card: #2E2E2E

Text Primary: #F8FAFC
Text Secondary: #94A3B8
Text Disabled: #64748B

Primary Blue: #60A5FA (lighter for dark backgrounds)
Success Green: #4ADE80
Error Red: #F87171
```

### Special Considerations
- Reduce elevation shadows (use subtle borders instead)
- Use subtle glows instead of heavy shadows
- Ensure M-Pesa green is still vibrant (#00D66F)
- Test all gradients for readability

---

## Empty States & Error Messages

### Empty States

**No Apps with Location Access:**
```
- Illustration: Shield with checkmark
- Headline: "All Clear!"
- Body: "No apps are currently accessing your location."
- Action: "View All Apps" button
```

**Search No Results:**
```
- Illustration: Magnifying glass with X
- Headline: "No Apps Found"
- Body: "Try a different search term or check your filters."
- Action: "Clear Search" link
```

**No Payment History:**
```
- Illustration: Empty receipt
- Headline: "No Transactions Yet"
- Body: "Your payment history will appear here."
```

### Error Messages

**Principles:**
- Be specific about what went wrong
- Explain why it matters
- Provide clear next steps
- Use friendly, non-technical language
- Avoid jargon

**Examples:**

"Couldn't load apps"
→ "We couldn't load your apps. Check your internet connection and try again."
Action: "Retry" button

"Permission denied"
→ "We need permission to view your installed apps. Please grant access in Settings."
Action: "Open Settings" button

"Payment failed"
→ "Your M-Pesa payment didn't go through. Please check your balance and try again."
Action: "Try Again" button

---

## Performance Optimization

### Image Loading
- Use Coil with crossfade transitions
- Placeholder: Solid color matching average app icon
- Cache aggressively
- Load app icons asynchronously

### List Performance
- RecyclerView with view recycling
- DiffUtil for efficient updates
- Smooth 60fps scrolling
- Pagination if >100 apps

### Animation Performance
- Use hardware acceleration
- Avoid overdraw
- Optimize Lottie animations (reduce size)
- Cancel animations on screen exit

---

## Premium Polish Checklist

Ensure these details are implemented:

- [ ] All corners are rounded (no sharp 90° corners)
- [ ] Consistent spacing throughout (multiples of 4dp)
- [ ] Smooth animations (no janky scrolling)
- [ ] Haptic feedback on key interactions
- [ ] Loading states for every async operation
- [ ] Error states with friendly messages
- [ ] Empty states with helpful illustrations
- [ ] Success celebrations (confetti for major actions)
- [ ] Branded color usage consistent
- [ ] Typography hierarchy clear
- [ ] Icons consistent style (all rounded)
- [ ] Shadows subtle and appropriate
- [ ] No placeholder text in production
- [ ] All strings localized
- [ ] Dark mode looks polished
- [ ] Transitions smooth and logical
- [ ] Touch feedback on all interactive elements
- [ ] Status bar color matches screen
- [ ] Navigation bar color matches screen
- [ ] Screenshots ready for Play Store

---

## Design Deliverables

You should create:

1. **Complete UI Kit in Figma/XD:**
   - All screens designed
   - Component library
   - Color styles
   - Text styles
   - Icon set

2. **Interactive Prototype:**
   - All main flows clickable
   - Realistic transitions
   - Shareable link for testing

3. **Design Specifications:**
   - Exact measurements (dp)
   - Color codes (hex)
   - Font specifications
   - Animation timings
   - Export as developer handoff

4. **Assets:**
   - App icon (all sizes)
   - Splash screen assets
   - Illustrations (SVG)
   - Lottie animations (JSON)
   - Icons (vector)

5. **Play Store Assets:**
   - Feature graphic (1024x500)
   - Screenshots (5-8, various devices)
   - App icon (512x512)
   - Promotional graphics

---

## Technical Implementation Notes

### Android Jetpack Compose Code Patterns

**For developers implementing this design:**

```kotlin
// Use Material 3 theming
MaterialTheme {
    colorScheme = if (darkMode) darkColorScheme else lightColorScheme
    typography = customTypography
    shapes = customShapes
}

// Consistent corner rounding
val shapes = Shapes(
    small = RoundedCornerShape(8.dp),
    medium = RoundedCornerShape(12.dp),
    large = RoundedCornerShape(16.dp),
    extraLarge = RoundedCornerShape(24.dp)
)

// Smooth animations
val animatedProgress by animateFloatAsState(
    targetValue = progress,
    animationSpec = tween(durationMillis = 300, easing = FastOutSlowInEasing)
)

// Haptic feedback
val haptic = LocalHapticFeedback.current
haptic.performHapticFeedback(HapticFeedbackType.LongPress)
```

---

## Final Notes

### Key Principles to Remember:
1. **Less is more** - Remove unnecessary elements
2. **Consistency is key** - Use design system throughout
3. **Speed matters** - Optimize for performance
4. **Delight users** - Add personality with animations
5. **Build trust** - Especially in payment flows
6. **Test on real devices** - Designs must work on actual phones
7. **Accessibility first** - Not an afterthought

### Avoid:
- ❌ Cluttered screens with too much info
- ❌ Tiny touch targets (<48dp)
- ❌ Slow animations (>400ms)
- ❌ Generic stock illustrations
- ❌ Inconsistent spacing
- ❌ Poor color contrast
- ❌ Jargon in copy
- ❌ Hidden actions (make CTAs obvious)

### Aim For:
- ✅ Clean, breathing layouts
- ✅ Obvious next actions
- ✅ Instant feedback
- ✅ Delightful details
- ✅ Professional polish
- ✅ Accessible to all users
- ✅ Fast and responsive
- ✅ Trustworthy payment experience

---

## Success Criteria

Your design is successful if:
1. A first-time user can subscribe within 2 minutes
2. Users describe the app as "clean", "modern", and "easy"
3. The payment flow feels secure and trustworthy
4. The app feels premium (not like a free app)
5. Users want to screenshot and share it
6. Accessibility score >90% on testing tools
7. Performance: 60fps scrolling, <2s load times

---

**Remember:** You're not just designing an app, you're designing an experience. Every pixel, every animation, every word matters. Make it feel like a product users would happily pay for.

**Think:** "Would I pay for this? Does this feel premium? Is this delightful to use?"

Good luck! 🚀
