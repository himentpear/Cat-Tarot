class_name SplashScreen
extends CanvasLayer

signal splash_finished

const SVG_HEADER := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 500 400" width="500" height="400">'
const SVG_FOOTER := "</svg>"
const THEATRE_PATH := "res://scenes/theatre_menu.tscn"

const SVG_BADGE := """
<defs>
  <radialGradient id="bgGlow" cx="50%" cy="52%" r="48%">
    <stop offset="0%" stop-color="#F47B20" stop-opacity="0.24"/>
    <stop offset="60%" stop-color="#1D4E78" stop-opacity="0.10"/>
    <stop offset="100%" stop-color="#0B2239" stop-opacity="0"/>
  </radialGradient>
</defs>
<circle cx="255" cy="220" r="185" fill="url(#bgGlow)"/>
<circle cx="255" cy="220" r="152" fill="#0B2239"/>
<circle cx="255" cy="220" r="139" fill="none" stroke="#C8D4E0" stroke-width="7.5"/>
<circle cx="255" cy="220" r="135" fill="#0B2239"/>
"""

const SVG_GECKO := """
<g transform="translate(0, -10)">
  <path d="M 272 135 C 312 132, 356 168, 360 226 C 365 288, 326 346, 270 350 C 236 352, 222 325, 236 303 C 246 287, 268 292, 267 307 C 266 296, 250 296, 246 308 C 242 322, 258 336, 282 332 C 325 325, 344 275, 338 225 C 332 184, 305 158, 272 152 Z" fill="#8FA2B4"/>
  <path d="M 244 128 C 254 114, 284 110, 315 122 C 358 140, 384 186, 380 242 C 376 305, 332 356, 272 358 C 234 359, 214 333, 223 306 C 230 286, 254 281, 268 297 C 256 292, 240 298, 238 312 C 236 327, 254 340, 278 338 C 322 334, 354 288, 354 234 C 354 185, 326 150, 292 146 L 285 162 L 266 172 L 254 166 L 265 157 L 253 155 L 262 147 L 274 152 L 278 139 C 262 140, 242 138, 244 128 Z" fill="#D5DEE6" stroke="#0B2239" stroke-width="6" stroke-linejoin="round" stroke-linecap="round"/>
  <path d="M 340 232 L 314 220 C 306 218, 300 225, 304 234 L 316 256 L 298 254 L 294 263 L 306 268 L 296 276 L 304 282 L 328 275 C 338 272, 344 256, 340 232 Z" fill="#D5DEE6" stroke="#0B2239" stroke-width="5.5" stroke-linejoin="round" stroke-linecap="round"/>
  <circle cx="261" cy="126" r="8" fill="#F47B20" stroke="#0B2239" stroke-width="3"/>
  <circle cx="261" cy="126" r="3.5" fill="#0B2239"/>
  <path d="M 244 133 Q 258 138 274 134" fill="none" stroke="#0B2239" stroke-width="3" stroke-linecap="round"/>
  <circle cx="306" cy="132" r="4" fill="#7D91A6"/>
  <circle cx="324" cy="144" r="6" fill="#7D91A6"/>
  <circle cx="342" cy="162" r="5" fill="#7D91A6"/>
  <circle cx="355" cy="186" r="7" fill="#7D91A6"/>
  <circle cx="362" cy="215" r="4.5" fill="#7D91A6"/>
  <circle cx="364" cy="242" r="7.5" fill="#7D91A6"/>
  <circle cx="354" cy="274" r="5" fill="#7D91A6"/>
  <circle cx="342" cy="302" r="6" fill="#7D91A6"/>
  <circle cx="318" cy="328" r="5" fill="#7D91A6"/>
  <circle cx="292" cy="343" r="4" fill="#7D91A6"/>
  <circle cx="260" cy="345" r="3.5" fill="#7D91A6"/>
</g>
"""

const SVG_LYNX := """
<g transform="translate(0, -10)">
  <path d="M 76.5 76.5 L 87.2 91.5 L 89.0 76.5 C 94.5 90.0, 99.5 101.0, 105.0 107.0 C 115.0 114.0, 127.0 121.5, 138.0 130.0 L 112.0 152.0 L 92.5 164.0 L 89.5 151.0 C 85.0 137.0, 82.5 121.0, 82.0 101.0 C 80.5 92.0, 78.5 84.0, 76.5 76.5 Z" fill="#0B2239"/>
  <path d="M 106.5 117.5 C 116.0 123.5, 126.0 130.0, 135.0 136.2 C 126.5 138.2, 119.0 142.5, 112.4 148.2 C 112.4 137.5, 109.8 126.5, 106.5 117.5 Z" fill="#768899"/>
  <path d="M 91.0 99.5 C 95.5 112.0, 104.5 127.0, 110.2 148.8 C 106.5 151.0, 103.5 153.2, 100.8 159.2 L 97.2 151.5 L 103.2 152.5 L 95.5 144.0 L 103.0 145.0 L 92.0 134.5 C 90.2 123.0, 89.8 110.5, 91.0 99.5 Z" fill="#FFFFFF"/>
  <path d="M 145.0 136.0 C 159.0 120.0, 175.0 101.0, 188.0 81.0 L 197.5 59.5 L 195.8 81.5 L 215.5 59.5 L 201.5 87.5 C 212.5 105.0, 215.5 128.0, 211.0 151.0 L 202.0 172.0 L 211.5 166.0 L 233.5 190.0 L 206.0 187.5 L 222.0 206.5 L 195.0 232.0 L 172.0 262.0 L 120.0 286.0 C 106.0 278.0, 99.5 270.0, 95.5 262.5 C 83.5 258.5, 76.5 249.0, 76.5 236.0 C 76.5 229.0, 79.0 223.5, 81.0 221.2 C 76.2 214.0, 76.0 207.0, 78.8 201.8 L 73.5 193.0 C 73.2 190.5, 80.5 179.0, 93.0 162.5 C 104.5 148.0, 122.0 138.0, 145.0 136.0 Z" fill="#0B2239"/>
  <path d="M 193.5 96.2 L 160.0 135.0 C 151.5 145.5, 143.5 156.5, 138.8 164.0 C 138.8 156.5, 141.0 148.5, 146.5 140.0 C 132.5 143.0, 118.5 151.5, 106.5 163.5 C 97.5 173.0, 90.5 182.5, 84.5 191.5 L 91.0 193.0 C 94.0 197.0, 95.0 203.0, 93.0 214.0 L 84.5 232.5 C 91.0 232.0, 99.0 231.5, 105.0 232.0 L 111.5 229.0 C 109.5 234.5, 108.5 237.5, 103.0 243.0 C 115.0 231.0, 126.0 228.5, 136.0 232.0 C 148.0 226.0, 162.0 224.0, 178.0 225.0 L 194.0 206.0 C 184.0 201.0, 168.0 198.0, 152.0 196.0 L 160.0 192.0 C 176.0 190.5, 195.0 192.5, 217.5 203.5 C 209.0 193.0, 196.0 185.0, 184.0 181.5 L 227.5 187.5 C 219.5 177.5, 211.5 170.5, 210.5 169.5 L 195.5 178.0 C 202.5 164.5, 206.5 150.0, 206.8 134.5 C 206.0 119.5, 200.8 106.0, 193.5 96.2 Z" fill="#C5D0DA"/>
  <path d="M 129.2 178.2 L 142.0 177.5 L 128.9 184.8 Z" fill="#8E9FAE"/>
  <path d="M 93.5 208.0 C 98.0 206.0, 106.0 208.0, 109.6 218.4 L 120.5 216.8 C 128.0 222.0, 134.0 226.5, 135.5 231.5 C 126.0 228.8, 118.0 230.2, 110.5 234.5 L 111.3 229.4 L 104.5 233.2 L 84.5 233.5 L 92.2 213.5 Z" fill="#BAC6D2"/>
  <path d="M 193.5 96.2 C 200.8 106.0, 205.6 120.0, 205.4 134.7 C 204.5 141.5, 200.5 148.2, 195.8 153.4 C 194.4 147.0, 197.2 140.5, 198.8 134.5 C 199.0 122.0, 196.2 109.5, 191.8 101.5 Z" fill="#F47B20"/>
  <path d="M 193.5 96.2 C 198.5 112.0, 199.2 132.0, 195.8 153.4 L 191.7 164.5 L 188.4 172.2 L 180.5 166.0 L 184.5 159.5 L 161.0 162.5 C 156.5 153.0, 160.0 138.0, 193.5 96.2 Z" fill="#0B2239"/>
  <path d="M 193.5 96.2 L 167.0 129.0 C 157.5 141.5, 156.5 154.0, 161.5 162.5 L 184.0 160.2 L 166.8 161.5 L 176.2 152.0 L 167.4 153.2 L 180.5 140.5 L 168.2 141.8 L 183.8 128.0 L 171.5 130.8 L 193.5 96.2 Z" fill="#FFFFFF"/>
  <path d="M 173.5 174.5 L 188.5 180.0 L 174.2 175.4 Z" fill="#0B2239"/>
  <path d="M 96.2 175.5 C 92.2 180.5, 89.8 186.5, 90.8 193.0 C 92.2 188.0, 94.0 182.0, 96.2 175.5 Z" fill="#0B2239"/>
  <path d="M 100.4 190.5 C 99.0 184.5, 102.5 174.5, 110.0 163.5 C 117.5 152.5, 128.0 142.5, 141.5 135.5 C 131.5 143.5, 121.0 153.5, 113.0 165.5 C 105.5 176.5, 102.2 184.5, 100.4 190.5 Z" fill="#0B2239"/>
  <circle cx="103.2" cy="169.6" r="1.7" fill="#0B2239"/>
  <circle cx="111.8" cy="182.4" r="1.8" fill="#0B2239"/>
  <circle cx="117.5" cy="174.1" r="1.9" fill="#0B2239"/>
  <circle cx="123.4" cy="164.5" r="2.1" fill="#0B2239"/>
  <path d="M 125.6 157.8 C 125.2 155.5, 126.8 153.2, 128.8 153.6 C 129.6 155.2, 128.4 158.2, 126.5 158.6 Z" fill="#0B2239"/>
  <path d="M 93.6 177.7 C 89.5 181.5, 85.5 186.5, 83.7 190.3 L 84.3 193.1 C 89.2 195.5, 92.8 199.0, 93.4 204.5 C 93.2 210.5, 91.8 215.5, 90.3 219.5 C 93.8 213.5, 95.2 206.5, 94.6 199.8 C 94.0 195.5, 91.5 193.2, 89.8 191.5 C 89.6 186.5, 91.2 181.8, 93.6 177.7 Z" fill="#FFFFFF"/>
  <path d="M 84.8 209.1 L 89.2 213.5 L 88.1 217.3 L 85.4 212.9 Z" fill="#FFFFFF"/>
  <path d="M 86.4 199.8 C 85.6 202.8, 86.4 206.4, 88.9 208.2 C 89.4 205.4, 88.6 201.6, 86.4 199.8 Z" fill="#F47B20"/>
  <path d="M 109.6 218.4 C 109.4 209.0, 111.5 201.5, 115.1 195.3 C 114.4 189.0, 117.2 181.5, 123.4 176.6 C 120.8 183.5, 120.2 189.0, 121.2 193.7 C 126.5 186.8, 133.5 181.5, 138.8 180.4 C 144.5 180.2, 152.0 182.8, 159.7 185.4 C 154.0 188.5, 148.5 191.2, 145.5 191.4 L 131.2 191.4 C 126.2 192.2, 121.8 196.2, 118.8 201.5 C 115.8 207.0, 113.5 214.0, 109.6 218.4 Z" fill="#FFFFFF"/>
  <path d="M 120.6 216.8 C 123.2 213.8, 126.2 212.0, 133.3 211.0 C 139.8 209.5, 144.8 204.5, 149.8 196.8 L 157.8 197.0 C 154.0 203.2, 149.2 208.2, 143.5 210.8 C 136.5 214.0, 128.5 215.5, 120.6 216.8 Z" fill="#FFFFFF"/>
  <path d="M 121.2 193.2 C 121.2 186.5, 123.2 178.5, 126.9 172.5 C 128.8 176.2, 129.6 180.2, 129.1 184.4 C 133.2 181.8, 137.5 179.6, 141.5 177.8 C 137.2 180.8, 132.5 183.6, 128.2 186.5 C 125.5 188.5, 123.0 190.8, 121.2 193.2 Z" fill="#0B2239"/>
  <path d="M 110.2 219.0 C 113.8 212.5, 116.8 204.0, 120.6 199.5 C 124.5 194.6, 128.0 192.0, 131.6 191.8 L 146.0 191.8 C 150.8 190.5, 156.2 188.0, 161.8 185.6 C 158.8 188.5, 155.2 190.8, 152.6 192.6 C 162.5 192.8, 174.5 191.0, 185.5 191.5 C 196.5 192.5, 206.0 197.0, 215.0 203.0 L 201.5 212.5 C 193.5 205.5, 184.0 200.8, 158.6 197.0 L 150.5 195.3 C 147.2 198.2, 143.8 205.0, 138.8 208.2 C 133.8 211.0, 127.0 211.2, 124.2 212.4 C 120.2 215.5, 114.8 217.0, 110.2 219.0 Z" fill="#0B2239"/>
  <path d="M 127.6 200.2 C 129.4 198.4, 136.0 195.8, 141.6 196.4 C 142.3 199.5, 141.8 202.8, 138.8 205.8 C 135.5 208.4, 130.2 208.5, 128.2 205.8 C 127.2 204.2, 127.2 201.6, 127.6 200.2 Z" fill="#F47B20"/>
  <path d="M 130.3 197.6 C 130.6 201.2, 131.6 204.2, 133.3 205.4 C 134.8 204.0, 135.6 200.8, 135.5 196.2 L 130.3 197.2 Z" fill="#0B2239"/>
  <path d="M 128.3 217.2 C 137.8 214.2, 146.5 209.8, 150.9 206.2 L 158.1 203.5 C 154.5 208.5, 147.5 213.2, 137.7 216.4 Z" fill="#0B2239"/>
  <path d="M 139.3 224.5 C 149.8 220.2, 159.5 215.0, 164.1 212.4 L 169.1 211.8 C 163.5 217.5, 153.5 221.5, 139.3 224.5 Z" fill="#0B2239"/>
  <path d="M 83.7 239.9 C 83.5 246.5, 86.8 252.5, 94.7 256.4 C 97.2 254.2, 97.6 252.2, 95.3 249.5 C 91.2 246.2, 87.2 243.0, 83.7 239.9 Z" fill="#FFFFFF"/>
  <path d="M 110.2 235.0 C 117.5 230.2, 126.5 229.0, 134.5 233.0 C 144.0 227.5, 158.0 225.5, 174.0 226.0 L 166.0 247.5 C 154.0 246.5, 144.5 247.0, 136.5 248.5 C 127.5 254.8, 116.5 256.5, 106.5 253.8 C 100.2 251.5, 98.8 248.0, 101.2 244.8 C 105.5 241.0, 108.8 238.0, 110.2 235.0 Z" fill="#FFFFFF"/>
  <path d="M 132.0 231.5 C 138.5 233.5, 142.8 239.5, 141.5 246.5 L 144.2 246.2 C 145.2 238.5, 140.5 232.0, 134.5 230.2 Z" fill="#C5D0DA"/>
  <path d="M 100.8 260.5 C 109.5 260.8, 121.0 260.2, 130.5 256.5 C 136.5 253.5, 140.5 249.0, 142.5 247.5 L 160.5 248.0 C 147.0 254.5, 132.0 265.5, 119.5 279.0 C 110.5 273.5, 103.5 267.5, 100.8 263.0 Z" fill="#FFFFFF"/>
  <path d="M 86.2 235.5 C 92.5 234.5, 99.5 233.5, 104.7 235.0 C 104.5 237.2, 102.5 237.8, 99.1 237.7 C 96.5 238.5, 95.8 240.5, 95.6 243.8 C 91.5 242.0, 87.8 238.8, 86.2 235.5 Z" fill="#F47B20"/>
  <path d="M 99.5 250.0 C 106.5 255.8, 118.5 257.2, 128.5 252.8 C 135.5 249.5, 140.5 243.5, 142.5 238.0 L 147.5 237.5 C 144.5 246.5, 137.5 254.8, 127.5 258.5 C 116.5 261.8, 104.5 260.5, 96.5 254.5 Z" fill="#0B2239"/>
  <circle cx="114.6" cy="243.2" r="1.5" fill="#0B2239"/>
  <circle cx="120.2" cy="241.2" r="1.7" fill="#0B2239"/>
  <circle cx="121.2" cy="246.2" r="1.8" fill="#0B2239"/>
  <path d="M 78.0 233.5 C 71.0 232.8, 66.0 232.8, 62.5 233.2 C 66.5 234.2, 72.0 235.0, 77.5 235.8 Z" fill="#0B2239"/>
  <path d="M 77.5 239.5 C 70.0 240.5, 64.0 242.2, 60.5 244.0 C 65.5 243.2, 71.5 242.2, 77.8 241.8 Z" fill="#0B2239"/>
  <path d="M 79.0 245.5 L 72.0 248.5 L 79.5 246.8 Z" fill="#0B2239"/>
  <path d="M 124.0 238.5 C 139.0 232.0, 156.0 228.0, 174.0 226.5 L 173.0 228.5 C 156.0 230.5, 139.5 234.8, 124.8 240.2 Z" fill="#0B2239"/>
  <path d="M 125.5 244.8 C 141.0 239.5, 156.5 236.5, 171.0 235.5 L 170.0 237.8 C 155.5 239.0, 141.0 242.0, 126.2 246.5 Z" fill="#0B2239"/>
  <path d="M 130.0 247.0 C 143.0 245.8, 155.5 246.2, 166.5 247.5 L 165.8 249.0 C 155.0 248.0, 142.5 247.8, 130.2 248.2 Z" fill="#0B2239"/>
</g>
"""

const SVG_GAMEPAD := """
<g transform="translate(0, -10)">
  <path d="M 214 202 L 246 202 L 252 222 L 258 202 L 292 202 C 310 202, 322 216, 326 238 L 334 286 C 337 308, 316 322, 298 306 L 278 278 C 272 271, 266 270, 256 270 L 258 250 L 247 250 L 245 270 C 238 270, 232 272, 226 278 L 206 306 C 188 322, 167 308, 170 286 L 178 238 C 182 216, 196 202, 214 202 Z" fill="#DDE5ED" stroke="#0B2239" stroke-width="7" stroke-linejoin="round"/>
  <path d="M 173 276 C 184 274, 198 264, 212 252 L 238 252 L 236 266 C 228 268, 220 274, 206 298 C 192 312, 171 302, 173 276 Z" fill="#8FA2B4"/>
  <path d="M 331 276 C 320 274, 306 264, 292 252 L 266 252 L 268 266 C 276 268, 284 274, 298 298 C 312 312, 333 302, 331 276 Z" fill="#8FA2B4"/>
  <path d="M 214 202 L 246 202 L 252 222 L 258 202 L 292 202 C 310 202, 322 216, 326 238 L 334 286 C 337 308, 316 322, 298 306 L 278 278 C 272 271, 266 270, 256 270 L 258 250 L 247 250 L 245 270 C 238 270, 232 272, 226 278 L 206 306 C 188 322, 167 308, 170 286 L 178 238 C 182 216, 196 202, 214 202 Z" fill="none" stroke="#0B2239" stroke-width="7" stroke-linejoin="round"/>
  <path d="M 210 218 H 222 V 230 H 234 V 242 H 222 V 254 H 210 V 242 H 198 V 230 H 210 Z" fill="#0B2239"/>
  <circle cx="294" cy="222" r="6.5" fill="#0B2239"/>
  <circle cx="294" cy="250" r="6.5" fill="#0B2239"/>
  <circle cx="280" cy="236" r="6.5" fill="#0B2239"/>
  <circle cx="308" cy="236" r="6.5" fill="#0B2239"/>
  <path d="M 239 224 L 244 230 M 267 224 L 262 230" stroke="#0B2239" stroke-width="4.5" stroke-linecap="round"/>
</g>
"""

const SVG_PAW := """
<g transform="translate(0, -10)">
  <path d="M 134 334 C 128 318, 142 304, 158 308 C 164 302, 178 304, 184 312 C 196 312, 206 326, 198 342 C 192 354, 176 358, 168 352 C 158 356, 144 350, 134 334 Z" fill="#F47B20" stroke="#0B2239" stroke-width="6" stroke-linejoin="round"/>
  <path d="M 154 318 C 150 328, 150 338, 154 346 M 176 320 C 172 330, 172 340, 176 348" fill="none" stroke="#0B2239" stroke-width="4.5" stroke-linecap="round"/>
  <path d="M 135 330 L 128 346 L 142 340 Z" fill="#FFFFFF" stroke="#0B2239" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M 155 340 L 152 358 L 164 346 Z" fill="#FFFFFF" stroke="#0B2239" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M 177 342 L 176 360 L 188 348 Z" fill="#FFFFFF" stroke="#0B2239" stroke-width="3.5" stroke-linejoin="round"/>
</g>
"""

const SVG_CRACK_FX := """
<g transform="translate(0, -10)">
  <path d="M 252 178 L 246 218 L 258 226 L 248 268 L 260 278 L 250 315" fill="none" stroke="#F47B20" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>
  <circle cx="252" cy="246" r="46" fill="none" stroke="#F47B20" stroke-width="3" stroke-dasharray="10 12"/>
</g>
"""

@export var studio_title: String = "GeckoLynx"
@export var studio_subtitle: String = "S t u d i o"
@export var next_scene_path: String = THEATRE_PATH
@export var auto_free_on_finish: bool = true
@export var allow_skip: bool = true

var _root: Control
var _bg: ColorRect
var _stage: Control
var _tex_badge: TextureRect
var _tex_gecko: TextureRect
var _tex_lynx: TextureRect
var _tex_gamepad: TextureRect
var _tex_paw: TextureRect
var _tex_fx: TextureRect
var _title_label: Label
var _sub_label: Label
var _tween: Tween
var _finished: bool = false


func _ready() -> void:
	if not next_scene_path.is_empty():
		ResourceLoader.load_threaded_request(next_scene_path, "PackedScene")
	if next_scene_path == THEATRE_PATH:
		TablePreloader.begin_load()
	layer = 100
	_build_nodes()
	_play_intro_sequence()


func _unhandled_input(event: InputEvent) -> void:
	if not allow_skip or _finished:
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			_finish_immediately()
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed:
			_finish_immediately()


func _build_nodes() -> void:
	_root = Control.new()
	_root.name = "SplashRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	_bg = ColorRect.new()
	_bg.color = Color(0.04, 0.05, 0.09, 1.0)
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	center.add_child(vbox)

	_stage = Control.new()
	_stage.custom_minimum_size = Vector2(400, 320)
	vbox.add_child(_stage)

	_tex_badge = _make_svg_layer(SVG_BADGE, Vector2(204, 176))
	_tex_gecko = _make_svg_layer(SVG_GECKO, Vector2(204, 176))
	_tex_lynx = _make_svg_layer(SVG_LYNX, Vector2(204, 176))
	_tex_gamepad = _make_svg_layer(SVG_GAMEPAD, Vector2(204, 195))
	_tex_paw = _make_svg_layer(SVG_PAW, Vector2(132, 256))
	_tex_fx = _make_svg_layer(SVG_CRACK_FX, Vector2(204, 195))

	var title_font := SystemFont.new()
	title_font.font_names = PackedStringArray(["Segoe UI", "Arial", "Helvetica", "sans-serif"])
	title_font.font_weight = 900

	_title_label = Label.new()
	_title_label.text = studio_title
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_override("font", title_font)
	_title_label.add_theme_font_size_override("font_size", 48)
	_title_label.add_theme_color_override("font_color", Color(0.95, 0.97, 0.99, 1.0))
	vbox.add_child(_title_label)

	var sub_font := SystemFont.new()
	sub_font.font_names = PackedStringArray(["Segoe UI", "Arial", "Helvetica", "sans-serif"])
	sub_font.font_weight = 500

	_sub_label = Label.new()
	_sub_label.text = studio_subtitle
	_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_label.add_theme_font_override("font", sub_font)
	_sub_label.add_theme_font_size_override("font_size", 24)
	_sub_label.add_theme_color_override("font_color", Color(0.78, 0.83, 0.89, 1.0))
	vbox.add_child(_sub_label)


func _make_svg_layer(inner_svg: String, pivot: Vector2) -> TextureRect:
	var img := Image.new()
	var full_svg := SVG_HEADER + inner_svg + SVG_FOOTER
	img.load_svg_from_string(full_svg, 2.0)
	var tex := ImageTexture.create_from_image(img)

	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.size = Vector2(400, 320)
	rect.pivot_offset = pivot
	_stage.add_child(rect)
	return rect


func _play_intro_sequence() -> void:
	_tex_badge.scale = Vector2.ZERO
	_tex_badge.rotation_degrees = -45.0
	_tex_badge.modulate.a = 0.0

	_tex_lynx.position = Vector2(-55, -24)
	_tex_lynx.scale = Vector2(0.82, 0.82)
	_tex_lynx.modulate.a = 0.0

	_tex_gecko.rotation_degrees = 68.0
	_tex_gecko.scale = Vector2(0.65, 0.65)
	_tex_gecko.modulate.a = 0.0

	_tex_gamepad.scale = Vector2(1.75, 1.75)
	_tex_gamepad.position = Vector2(0, -18)
	_tex_gamepad.modulate.a = 0.0

	_tex_paw.position = Vector2(-35, 35)
	_tex_paw.scale = Vector2(1.4, 1.4)
	_tex_paw.modulate.a = 0.0

	_tex_fx.modulate.a = 0.0
	_tex_fx.scale = Vector2(0.85, 0.85)

	_title_label.modulate.a = 0.0
	_sub_label.modulate.a = 0.0

	_tween = create_tween()

	# Stage 1 (0.05s): Medallion badge awakens with elastic overshoot
	_tween.tween_callback(func() -> void: Audio.play_sfx("card_draw", -6.0, 0.85)).set_delay(0.05)
	_tween.parallel().tween_property(_tex_badge, "modulate:a", 1.0, 0.20).set_delay(0.05)
	_tween.parallel().tween_property(_tex_badge, "scale", Vector2.ONE, 0.52).set_delay(0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_tex_badge, "rotation_degrees", 0.0, 0.52).set_delay(0.05).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Stage 2 (0.35s): Lynx breaks in from top-left; Gecko slithers along right arc
	_tween.parallel().tween_callback(func() -> void: Audio.play_sfx("card_slide", -5.0, 1.05)).set_delay(0.35)
	_tween.parallel().tween_property(_tex_lynx, "modulate:a", 1.0, 0.18).set_delay(0.35)
	_tween.parallel().tween_property(_tex_lynx, "position", Vector2.ZERO, 0.48).set_delay(0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_tex_lynx, "scale", Vector2.ONE, 0.48).set_delay(0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_tween.parallel().tween_property(_tex_gecko, "modulate:a", 1.0, 0.22).set_delay(0.42)
	_tween.parallel().tween_property(_tex_gecko, "rotation_degrees", 0.0, 0.56).set_delay(0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_tex_gecko, "scale", Vector2.ONE, 0.56).set_delay(0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Stage 3 (0.85s): Controller slam & orange paw lock + crack flash + screen shake
	_tween.parallel().tween_property(_tex_gamepad, "modulate:a", 1.0, 0.12).set_delay(0.85)
	_tween.parallel().tween_property(_tex_gamepad, "scale", Vector2.ONE, 0.38).set_delay(0.85).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_tex_gamepad, "position", Vector2.ZERO, 0.38).set_delay(0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	_tween.parallel().tween_property(_tex_paw, "modulate:a", 1.0, 0.12).set_delay(0.94)
	_tween.parallel().tween_property(_tex_paw, "position", Vector2.ZERO, 0.34).set_delay(0.94).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_tex_paw, "scale", Vector2.ONE, 0.34).set_delay(0.94).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_tween.parallel().tween_callback(_trigger_impact_fx).set_delay(0.96)

	# Stage 4 (1.20s): Studio wordmark reveal
	_tween.parallel().tween_callback(func() -> void: Audio.play_sfx("card_reveal", -5.0, 1.0)).set_delay(1.20)
	_tween.parallel().tween_property(_title_label, "modulate:a", 1.0, 0.45).set_delay(1.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_sub_label, "modulate:a", 1.0, 0.50).set_delay(1.36).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Hold the logo until the incoming scene can be drawn behind it.
	_tween.tween_interval(0.85)
	if next_scene_path.is_empty():
		_tween.tween_property(_root, "modulate:a", 0.0, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(_on_sequence_complete)


func _trigger_impact_fx() -> void:
	Audio.play_sfx("card_tap", -2.0, 0.78)
	_tex_fx.modulate.a = 1.0
	var fx_tween := create_tween()
	fx_tween.set_parallel(true)
	fx_tween.tween_property(_tex_fx, "scale", Vector2(1.12, 1.12), 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fx_tween.tween_property(_tex_fx, "modulate:a", 0.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var glow_tween := create_tween()
	glow_tween.tween_property(_tex_lynx, "self_modulate", Color(1.22, 1.12, 1.0, 1.0), 0.14)
	glow_tween.tween_property(_tex_lynx, "self_modulate", Color.WHITE, 0.28)

	var base_pos := _stage.position
	var shake := create_tween()
	shake.tween_property(_stage, "position", base_pos + Vector2(-6, 4), 0.04)
	shake.tween_property(_stage, "position", base_pos + Vector2(6, -3), 0.04)
	shake.tween_property(_stage, "position", base_pos + Vector2(-3, -2), 0.04)
	shake.tween_property(_stage, "position", base_pos, 0.04)


func _finish_immediately() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_on_sequence_complete()


func _on_sequence_complete() -> void:
	if _finished:
		return
	_finished = true
	splash_finished.emit()
	if not next_scene_path.is_empty():
		_open_next_scene()
	elif auto_free_on_finish:
		queue_free()


func _open_next_scene() -> void:
	var tree := get_tree()
	if next_scene_path == THEATRE_PATH and not TablePreloader.finished:
		TablePreloader.prepare()
		await TablePreloader.preparation_finished
	var status := ResourceLoader.load_threaded_get_status(next_scene_path)
	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await tree.process_frame
		status = ResourceLoader.load_threaded_get_status(next_scene_path)
	var next_scene: PackedScene
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		next_scene = ResourceLoader.load_threaded_get(next_scene_path) as PackedScene
	else:
		next_scene = load(next_scene_path) as PackedScene
	if next_scene == null:
		push_error("Could not load the scene after the studio splash")
		return

	# Swap before the frame is processed, leaving a cover through the first rendered frame.
	await tree.process_frame
	var cover: SplashCover
	if DisplayServer.get_name() != "headless":
		cover = SplashCover.new()
		cover.layer = 10
		tree.root.add_child(cover)
		_root.reparent(cover, false)
	if tree.change_scene_to_packed(next_scene) == OK:
		if cover != null:
			cover.dissolve(_root)
	elif cover != null:
		_root.reparent(self, false)
		cover.queue_free()


class SplashCover extends CanvasLayer:
	func dissolve(logo: Control) -> void:
		await get_tree().scene_changed
		await RenderingServer.frame_post_draw
		var fade := create_tween()
		fade.tween_property(logo, "modulate:a", 0.0, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		fade.tween_callback(queue_free)
