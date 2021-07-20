#pragma once

#include <Guiddef.h>
// {1454EBE8-94FD-464F-B23F-B7411C7A1286}
DEFINE_GUID(KEY_IVPN_ST_PROVIDER,
	0x1454ebe8, 0x94fd, 0x464f, 0xb2, 0x3f, 0xb7, 0x41, 0x1c, 0x7a, 0x12, 0x86);
// {D267063D-ED71-4B65-8CBD-876296174F6B}
DEFINE_GUID(KEY_IVPN_ST_SUBLAYER,
	0xd267063d, 0xed71, 0x4b65, 0x8c, 0xbd, 0x87, 0x62, 0x96, 0x17, 0x4f, 0x6b);


// Provider key used by IVPN firewall
//DEFINE_GUID(KEY_IVPN_FW_PROVIDER,
//	0xfed0afd4, 0x98d4, 0x4233, 0xa4, 0xf3, 0x8b, 0x7c, 0x02, 0x44, 0x50, 0x01);
// Sublayer key used by IVPN firewall
DEFINE_GUID(KEY_IVPN_FW_SUBLAYER,
	0xfed0afd4, 0x98d4, 0x4233, 0xa4, 0xf3, 0x8b, 0x7c, 0x02, 0x44, 0x50, 0x02);

//
// CALLOUTS
// 

// {409A204B-1CB9-424A-BF04-A296C220FEBD}
DEFINE_GUID(KEY_CALLOUT_ALE_BIND_REDIRECT_V4,
	0x409a204b, 0x1cb9, 0x424a, 0xbf, 0x4, 0xa2, 0x96, 0xc2, 0x20, 0xfe, 0xbd);
// {FCA5543A-AD22-4DDC-B32A-CAFB9792A517}
DEFINE_GUID(KEY_CALLOUT_ALE_CONNECT_REDIRECT_V4,
	0xfca5543a, 0xad22, 0x4ddc, 0xb3, 0x2a, 0xca, 0xfb, 0x97, 0x92, 0xa5, 0x17);
// {563B569E-FE81-49B2-BEFE-F83973BC4AF4}
DEFINE_GUID(KEY_CALLOUT_ALE_BIND_REDIRECT_V6,
	0x563b569e, 0xfe81, 0x49b2, 0xbe, 0xfe, 0xf8, 0x39, 0x73, 0xbc, 0x4a, 0xf4);
// {4612064F-F055-44F2-AA59-6AA18E02A84A}
DEFINE_GUID(KEY_CALLOUT_ALE_CONNECT_REDIRECT_V6,
	0x4612064f, 0xf055, 0x44f2, 0xaa, 0x59, 0x6a, 0xa1, 0x8e, 0x2, 0xa8, 0x4a);

//
// NOTE: The callout GUIDs (bellow) can be used by external applications in order to allow all communications for applications which have to be splitted
// (e.g. it is in use by IVPN firewall to bypass its default blocking rule)
// 

// {100DD8BC-5C6C-4989-99CF-EB93B14AFA69}
DEFINE_GUID(KEY_CALLOUT_ALE_AUTH_CONNECT_V4,
	0x100dd8bc, 0x5c6c, 0x4989, 0x99, 0xcf, 0xeb, 0x93, 0xb1, 0x4a, 0xfa, 0x69);
// {7C4E6A94-7284-4592-B394-B3369770F30D}
DEFINE_GUID(KEY_CALLOUT_ALE_AUTH_CONNECT_V6,
	0x7c4e6a94, 0x7284, 0x4592, 0xb3, 0x94, 0xb3, 0x36, 0x97, 0x70, 0xf3, 0xd);
// {D7FD0B39-89FE-4E13-9FE4-52F97170F098}
DEFINE_GUID(KEY_CALLOUT_ALE_AUTH_RECV_ACCEPT_V4,
	0xd7fd0b39, 0x89fe, 0x4e13, 0x9f, 0xe4, 0x52, 0xf9, 0x71, 0x70, 0xf0, 0x98);
// {67C57157-8A6B-4AF2-8DAA-5F06372F5DAB}
DEFINE_GUID(KEY_CALLOUT_ALE_AUTH_RECV_ACCEPT_V6,
	0x67c57157, 0x8a6b, 0x4af2, 0x8d, 0xaa, 0x5f, 0x6, 0x37, 0x2f, 0x5d, 0xab);

//
// FILTERS
//

// {DC3B8AA4-B974-4781-8F3E-1B105CAE7D3A}
DEFINE_GUID(KEY_FILTER_CALLOUT_ALE_BIND_REDIRECT_V4,
	0xdc3b8aa4, 0xb974, 0x4781, 0x8f, 0x3e, 0x1b, 0x10, 0x5c, 0xae, 0x7d, 0x3a);
// {EE0E35E7-74AD-407A-9F8B-EF9BB50F17C8}
DEFINE_GUID(KEY_FILTER_CALLOUT_ALE_CONNECT_REDIRECT_V4,
	0xee0e35e7, 0x74ad, 0x407a, 0x9f, 0x8b, 0xef, 0x9b, 0xb5, 0xf, 0x17, 0xc8);
// {182E81CD-EAC4-46F9-863B-27BBB51941F3}
DEFINE_GUID(KEY_FILTER_CALLOUT_ALE_BIND_REDIRECT_V6,
	0x182e81cd, 0xeac4, 0x46f9, 0x86, 0x3b, 0x27, 0xbb, 0xb5, 0x19, 0x41, 0xf3);
// {3D9BC339-B1E9-44A8-A6C1-6321986216F0}
DEFINE_GUID(KEY_FILTER_CALLOUT_ALE_CONNECT_REDIRECT_V6,
	0x3d9bc339, 0xb1e9, 0x44a8, 0xa6, 0xc1, 0x63, 0x21, 0x98, 0x62, 0x16, 0xf0);

