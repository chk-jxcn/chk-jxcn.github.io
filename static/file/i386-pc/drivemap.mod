ELF                      �      4     (   ���    ��tNU����L   �   ������        �L   QQ��R��Ph    h#   hk  h,   ������� 1���1��U��WVS���=    u�H   ������R�e   ������   ��t>�S�׃�������f�s�����������F��WRVQPh�   �������� �1��e�[^_]�U��WVS���É׀8(uC��p����   u1�{du+<hu������C1�1�������=     u��w	��1��PSh�   j��������e�[^_]�U��S���È��   ��t8Ht� ��P1��/�U��   ������    ���U�t�X�P�   ��   �͉ȃ�[]���U��WVS��,�ǋ@�8 t�e�[^_]�����x t%�   ��t�����������       1��'  �Ή�Ht��E� �E����tRRh�   j������Ã���   �U������Å���   �F�U������Å���   �E��M��U�:E�uBPPQRh  h#   h�   h,   ������u�   �� 1Ʌ���   �8��:Pto������^�w��   �~ u��   ��Q�u�PSRh2  h#   h  h,   �������0�U��E��c����ËG�x t(��u$�U��E��G��������t�9��=   ������؍e�[^_]���U��SP�L  �������t1�1�[[]�����1�����������t7���t,�Q��t%�z u�   �Y��t�J9�u�Z�����������Z[]���U��WVS���   1���tG� ����u!hT  h#   h)  h,   ��������  h�  h#   h.  h,   ������L   �    Y[��R��Ph�  h#   h2  h,   ������G��E�    ��    �0��Sh�  h#   h:  h,   �������jjh   �C���1�RP�   1�������Ã���uRRh�  j��������  ��Ph!  h#   hD  h,   ������� ��    ��������   �E܍3�E��PhI  h#   hM  h,   ������� 1��E܊H�U�r�P�E܋E�TpPR��RVhm  h#   hR  h,   �����F�E܋ �� 9�u��E�M�f�D�  ��Wh�  h#   hX  h,   ��������L   ����P��Sh�  h#   h\  h,   ������� 1��e�[^_]���U����    �    �      h    h�  h�  1ɺ�  �#   ������   X��  �    ��  ������   ����U����    �    �   ������       �   �������R�PS�H .�8�tCC8�u��[X��t��t��.�C U��Z�V]Zϝ�.�C U��V��    �  �  l                   r       "          L  s       Q                                  Restored int13 handler: %04x:%04x
 drivemap commands/i386/pc/drivemap.c No drives have been remapped OS disk #num ------> GRUB/BIOS device %cD #%-3u (0x%02x)       %cd%d
 device format "%s" invalid: must be (f|h)dN, with 0 <= N < 128 Swapping Mapping two arguments expected Removing mapping for %s (%02x)
 %s %s (%02x) = %s (%02x)
 biosnum No drives marked as remapped, not installing our int13h handler.
 Installing our int13h handler
 Original int13 handler: %04x:%04x
 Payload is %u bytes long
 couldn't reserve memory for the int13h handler Reserved memory at %p, copying handler
 Target map at %p, copying mappings
 	#%d: 0x%02x <- 0x%02x
 	#%d: 0x00 <- 0x00 (end)
 New int13 handler: %04x:%04x
 Manage the BIOS drive mappings. -l | -r | [-s] grubdev osdisk. list Show the current mappings. reset Reset all mappings to the default values. swap Perform both direct and reverse mappings.  LICENSE=GPLv3+  extcmd boot mmap drivemap                                                                              �  _        �  3                   (              5              F              d              {   e        �              �              �              �              �   "        �              
  j        !             ?             Q             c             n             x             �             �             �              grub_mod_init grub_mod_fini grub_puts_ grub_memmove grub_device_open grub_mmap_free_and_unregister grub_unregister_extcmd grub_drivemap_oldhandler grub_errno grub_printf grub_get_root_biosnumber grub_loader_unregister_preboot_hook grub_drivemap_handler grub_malloc grub_drivemap_mapstart grub_mmap_malign_and_register grub_real_dprintf grub_device_close grub_error grub_free grub_loader_register_preboot_hook grub_register_extcmd grub_env_get grub_strtoul                 
  $     <     A     K     P     i     q     v     }     �     �     �     �             ,    3    N    o    u    �    �    �    �    �            Y    ^    h    m    v    �    �    �    �    �    �    	        &    +    ;    B  	  b    �    �    �    �    �    �    �    �    �    �    �    �    �    	            !    -    2    <    A    M    c    s    z    �    �    �    �    �    �    �    �    �    �    �                    =    B    L    Q    j    o    y    ~    �    �    �    �    �    �    �    �    �    �    �    �    �    �    �    �    �                                        $     0     <      .symtab .strtab .shstrtab .rel.text .rel.rodata .rodata.str1.1 .data .module_license .bss .moddeps .modname                                                         4   k                    	   @       D  �              )             �  `                   %   	   @       �  0               1      2          {                @             {
                     F             |
                    V             �
                    [              �
                    d              �
  	                                �
  �              	              x  �                               $  m                  