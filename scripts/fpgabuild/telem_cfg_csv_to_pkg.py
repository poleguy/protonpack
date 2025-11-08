import datetime
import sys
import math




class field():
    def __init__(self, num, bytes, id, units, descr):
        self.num = num
        self.bytes = bytes
        self.id = id
        self.units = units
        self.descr = descr

class stream():
    def __init__(self, num, id, fifo_addr_width, fifo_data_width, pkt_size, fifo_direct_mode):
        self.num=num
        self.id=id
        self.fifo_addr_width=fifo_addr_width
        self.fifo_data_width=fifo_data_width
        self.fifo_direct_mode=fifo_direct_mode
        self.pkt_size=pkt_size
        self.fields=[]
    def add_field(self, bytes, id, units, descr):
        self.fields.append(field(len(self.fields), bytes, id, units, descr))
    def getStreamNumFields(self):
        return len(self.fields)
    def getStreamTotalBytes(self):
        bytes=0
        for field in self.fields:
            bytes+=int(field.bytes)
        return bytes
    def getStreamNumFifoWords(self):
        """ If we are in fifo direct mode we are using the FIFO data width directly for the stream data size
        and there is only 1 write to fifo per stream valid.  This is the mechanism used for example for 
        mobile telemetry interface """
        if(self.fifo_direct_mode):
            return 1
        else:
            return int(int(self.getStreamTotalBytes())/int(self.getFifoDataWidth()/8))
    def getStreamFifoSDataWidth(self):
        """ Return the number of bits wide the s_data port should be going into stream_fifo module.
            If we are in fifo_direct_mode it should mirror the fifo data width.
            Otherwise it should be the total stream length in bits.
        """
        if(self.fifo_direct_mode):
            return self.fifo_data_width
        else:
            return self.getStreamTotalBytes()*8
    def getFifoAddrWidth(self):
        return self.fifo_addr_width
    def getFifoDataWidth(self):
        return self.fifo_data_width
    #def getUdpLength(self):
    #    return self.udp_len



#class telem_stream():
#    def __init__(self):
#        self.streams=[]
#    def add_stream(self):
#        self.streams.append(stream)

class telem_cfg_csv_to_pkg():



    ###########################################
    ## Telemetry Fixed Parameters
    ##
    ## These really should not change often and
    ## are more part of the fixed design rather
    ## and will likely require other changes in
    ## rtl and in the decoding side.
    ##
    ## Have them as class variables so you don't
    ## have to instantiate the class but instead
    ## can call telem_csv_config_parse() method
    ## directly.  No one *should* be instantiating
    ## this calss multiple times.
    ##
    TELEMETRY_VERSION           = 5
    #-- Number of bytes used for the ascii ID of the stream
    STREAM_ID_SIZE_BYTES         = 4
    #-- Number of bytes used for the ascii ID of the field
    FIELD_ID_SIZE_BYTES         = 4

    ###########################################################################################
    ## Note we want to limit the packet size to a relatively stadard MTU size of 1500 Bytes.
    ## If we don't it's possible Tx or Rx ends will fragment this packet into smaller packets.
    ## The receiving parsing won't know how to handle the UDP fragmentation.
    ##
    ## 1500B - 20B IP HDr - 8B UDP Header - 8B Eth FCS Chksum 
    ##            = 1464B avail for UDP payload (including our payload hdr)
    ##
    ## See ethernet frame structure at https://confluence.shure.com/display/PDDWIKI/FPGA+Ethernet+UDP
    ##
    ## In addition to limiting the MTU size, this also plays well with using 1 36kbit BRAM
    ## for each stream FIFO with plenty of buffering.
    ##   32kbit /8 = 4000 bytes depth in BRAM FIFO.. plenty of buffering for ~1400 byte packets
    ##
    MAX_PKT_UDP_DATA_SIZE_BYTES  = 1464
    ###########################################################################################
    #-- Number of bytes used for the Length of the Field
    FIELD_LEN_SIZE_BYTES        = 1
    #-- Number of btes used for the Length of the Field
    FIELD_ENABLE_SIZE_BYTES     = 4
    #-- Number of bytes used for the units/data type for each field
    FIELD_UNIT_TYPE_SIZE_BYTES   = 4
    MAX_NUM_FIELDS_PER_STREAM  = 128
    #-- This number is fixed based on the number of stream records and corresponding fixed
    #-- I/O setup within the telemetry module
    MAX_NUM_STREAMS             = 20
    #-- Used to fix the width of the enable field in the config packet
    STREAM_MAX_BYTES            = 256
    TIMESTAMP_SIZE_BYTES        = 4
    PAYLOAD_STATUS_SIZE_BYTES   = 12

    # Ports are by convention and parsing side expects them to be this way.
    # Stream0 is BASE_PORT+1 and so on
    PORT_DEST_CONFIG            = 4999 
    PORT_DEST_STREAM_BASE       = 5000
    STREAM_FIFO_ADDR_WIDTH      = 12

    # In this mode, stream_data and stream_valid are direct connects for fifo write
    # So far useful in the mobile telemetry application to write many fields incrementally.
    FIFO_DIRECT_MODE            = False

    STREAM_FIFO_DATA_WIDTH      = 8

    # In practice we want to use larger packets to reduce overhead. 
    # For sim it can be helpful to use the minimum packet seize which would be 
    # one payload and one sample set of field data.
    USE_MINIMUM_PKT_SIZE = False

    # Number of bits of input port per stream
    STREAM_USER_ERROR_BITS = 4


    def __init(self):
        pass

    def show_line_number(self, row, row_num, filename):
        return "\nLine "+str(row_num)+": "+ row.rstrip() + "  ("+filename+")"

    def telem_csv_cfg_parse(self, csv_filename):
        self.telem_cfg=[]
        with open(csv_filename, "r") as f:
            row_num=0
            for row in f:
                row_num=row_num+1
                row=row.strip()
                #print(row)
                if(len(row)>0):
                    if(row[0]!='#' and row[0]!='\n' and len(row)>0):

                        rs = row.rstrip().split(',')
                        ############################################
                        ##start new STREAM row
                        ############################################
                        if(rs[0].upper()=="STREAM"):
                            assert(int(rs[1])==len(self.telem_cfg)),f"ERROR expected STREAM number {len(self.telem_cfg)} Streams must be declared and used in numerical order and not skipped {self.show_line_number(row,row_num,csv_filename)}"
                            assert(len(rs) in range(3,8)),"ERROR Stream start fields must be in the range 3-6, should be: STREAM,<INT>,NAME[,fifo_addr_width=<INT>,fifo_data_width=<8 or 32>,udp_len=<INT>]"+self.show_line_number(row,row_num,csv_filename)
                            fifo_addr_width=self.STREAM_FIFO_ADDR_WIDTH
                            fifo_data_width=self.STREAM_FIFO_DATA_WIDTH
                            fifo_direct_mode=self.FIFO_DIRECT_MODE

                            # default setting - can be overwritten by each stream
                            if(self.USE_MINIMUM_PKT_SIZE):
                                pkt_size="min"
                            else:
                                pkt_size="max"

                            for i in range(3,len(rs)):
                                assert(rs[i].split('=')[0] == "fifo_addr_width" or "fifo_data_width" or "pkt_size" or "fifo_direct_mode"), "ERROR additional parameters can only be fifo_addr_width=<INT>,fifo_data_width=<8 or 32>,udp_len=<INT>,fifo_direct_mode"+show_line_number(row, row_num, csv_filename)
                                if(rs[i].split('=')[0]=="fifo_addr_width"):
                                    fifo_addr_width = int(rs[i].split('=')[1])
                                if(rs[i].split('=')[0]=="fifo_data_width"):
                                    fifo_data_width = int(rs[i].split('=')[1])
                                    assert(fifo_data_width % 8 == 0), "fifo_data_width can only be increment of 8 bits. All other widths are not accepted "+self.show_line_number(row,row_num,csv_filename)
                                if(rs[i].split('=')[0]=="pkt_size"):
                                    pkt_size = rs[i].split('=')[1]
                                if(rs[i].split('=')[0].lower()=="fifo_direct_mode"):
                                    fifo_direct_mode=True

                            ## If stream ascii length is less than specified size, increase it by appending spaces on end
                            if(len(rs[2])<=self.STREAM_ID_SIZE_BYTES):
                                stream_id=rs[2].ljust(self.STREAM_ID_SIZE_BYTES)
                            ## If it's greater than the specified size, that's an error
                            else:
                                assert(False),"ERROR stream ascii ID is not "+str(self.STREAM_ID_SIZE_BYTES)+" length "+self.show_line_number(row,row_num,csv_filename)

                            assert(int(rs[1])<=self.MAX_NUM_STREAMS-1), "ERROR field stream num is beyond the max number "+str(self.MAX_NUM_STREAMS)+self.show_line_number(row,row_num,csv_filename)

                            ## Final step for each stream where we append the stream containing fields to a running list self.telem_cfg
                            self.telem_cfg.append(stream(int(rs[1]),stream_id,fifo_addr_width,fifo_data_width,pkt_size,fifo_direct_mode))

                        ############################################
                        ##Tick ` parameter
                        ############################################
                        elif(rs[0][0]=='`'):
                            try:
                                no_tick=rs[0].split('`')[1]
                                split_equal=no_tick.split('=')
                                param=split_equal[0]
                                value=split_equal[1]
                                print(f"########### Tick parameter: {param}  value: {value}")
                            except:
                                raise ValueError(f'Tried to parse a tick parameter line: {rs[0].strip()} but failed.  Should be in the format   `FIELD_ID_SIZE_BYTES=8 ')
                            try:
                                s='self.'+param.upper()+'='+value
                                exec(s)
                            except:
                                raise Exception(f'Tried to set parameter based on {rs[0].strip()} failed.  evaluating python expression:  {s}')

                        ############################################
                        ## Not STREAM or `, assume it's a field
                        ############################################
                        else:
                            ## put some checking in
                            expect_csv_fields=5
                            assert(len(rs)==expect_csv_fields), "ERROR expected entires in csv file to have "+str(expect_csv_fields)+" fields per row"+self.show_line_number(row,row_num,csv_filename)
                            stream_num=rs[0]
                            length_bytes=rs[1]
                            field_id_temp=rs[2]
                            field_units_temp=rs[3]
                            field_descr=rs[4]
                            assert(self.telem_cfg!=[]),"ERROR Stream start fields not 3, should be:  STREAM,0,NAME"+self.show_line_number(row,row_num,csv_filename)
                            assert(stream_num.isnumeric()), "ERROR field stream num is not numeric"+self.show_line_number(row,row_num,csv_filename)
                            stream_num_int = int(stream_num)
                            assert(stream_num_int<=self.MAX_NUM_STREAMS-1), "ERROR field stream num is beyond the max number "+str(self.MAX_NUM_STREAMS)+self.show_line_number(row,row_num,csv_filename)
                            assert(length_bytes.isnumeric()), "ERROR stream field size bytes is not numeric"+self.show_line_number(row,row_num,csv_filename)

                            ## If field ascii length is less than specified size, increase it by appending spaces on end
                            if(len(field_id_temp)<=self.FIELD_ID_SIZE_BYTES):
                                field_id=field_id_temp.ljust(self.FIELD_ID_SIZE_BYTES)
                            ## If it's greater than the specified size, that's an error
                            else:
                                assert(False), "ERROR stream field ascii ID is greater than "+str(self.FIELD_ID_SIZE_BYTES)+" length "+self.show_line_number(row,row_num,csv_filename)

                            if(len(field_units_temp)<=self.FIELD_UNIT_TYPE_SIZE_BYTES):
                                field_units=field_units_temp.ljust(self.FIELD_UNIT_TYPE_SIZE_BYTES)
                            else:
                                assert(False), "ERROR stream field ascii ID is not "+str(self.FIELD_UNIT_TYPE_SIZE_BYTES)+" length "+self.show_line_number(row,row_num,csv_filename)
                            assert(self.telem_cfg[-1].num==stream_num_int),"ERROR field stream# does not equal last STREAM start syntax  STREAM,#,NAME"+self.show_line_number(row,row_num,csv_filename)
                            ## check for duplicate field names
                            for existing_field in self.telem_cfg[-1].fields:
                                if(field_id.strip().lower()==existing_field.id.strip().lower()):
                                    assert(False), f"ERROR duplicate field ascii ID found after stripping whitespace and changing to all lowercase... existing field {existing_field.id} new field {field_id} "+self.show_line_number(row,row_num,csv_filename)


                            self.telem_cfg[-1].add_field(length_bytes,field_id,field_units,field_descr)


        ############################################
        ## Put in a final check for each stream 
        ## to make sure fifo width makes sense
        ############################################
        for ii in range(len(self.telem_cfg)):
            fifo_data_width = self.telem_cfg[ii].getFifoDataWidth()
            stream_total_bytes = self.telem_cfg[ii].getStreamTotalBytes()
            assert(stream_total_bytes % int(fifo_data_width/8) == 0), f"ERROR Stream FIFO data width is {fifo_data_width/8} bytes, total number of stream byte is {stream_total_bytes} must be a multiple\nIn file"+ " ("+csv_filename+")"

        ### Now that we have read in all the csv cfg information.  Genearte some additional calculations and details from that info.
        self._calculate_telem_details()

    def _calculate_telem_details(self):
        """ Once the telemetry has been read in from csv, calculate some details before
            generating the vhdl package.
        """
        self._gen_config_pkt_rom()
        self._gen_config_pkt_lengths()

        # Figure out how many round robin items we have.  This would be 1 per each stream 
        # plus 1 for each config packet fragment.
        self.ROUND_ROBIN_ITEMS=self.MAX_NUM_STREAMS+self.cfg_num_pkts

        # gen packet sizes and fifo thresholds
        self._gen_pkt_sizes()

        self._gen_fifo_thresholds()


    def list_to_vhdl_str(self, ll, add_line_break_every=0):
        str_list=''
        first=True
        ## 0th array entry in vhdl is that last element in a list (index 2, index 1, index 0)
        cnt=0
        for l in ll:
            if(add_line_break_every!=0):
                if((cnt % add_line_break_every ==0) or (cnt==0)):
                    str_list=str_list+'\n        '
                    if(cnt==0):
                        str_list=str_list+' '
            if(first):
                str_list=str_list+str(l)
                first=False
            else:
                str_list=str_list+','+str(l)
            cnt=cnt+1
        return str_list

    def stream_lengths_str(self):
        lengths=[]
        for ii in range(0,self.MAX_NUM_STREAMS):
            if(ii<len(self.telem_cfg)):
                lengths.append(len(self.telem_cfg[ii].fields))
            else:
                lengths.append(0)
        return self.list_to_vhdl_str(lengths)
        #print('lengths=',lengths)
        #print("str_list=",str_list)

    def stream_total_bytes_str(self):
        bytes=[]
        for ii in range(0,self.MAX_NUM_STREAMS):
            if(ii<len(self.telem_cfg)):
                bytes.append(self.telem_cfg[ii].getStreamTotalBytes())
            else:
                bytes.append(0)
        return self.list_to_vhdl_str(bytes)

    def stream_total_bits_left_str(self):
        bytes=[]
        for ii in range(0,self.MAX_NUM_STREAMS):
            if(ii<len(self.telem_cfg)):
                bytes.append((self.telem_cfg[ii].getStreamTotalBytes()*8) -1)
            else:
                bytes.append(0)
        return self.list_to_vhdl_str(bytes)

    def stream_sdata_width_str(self):
        widths=[]
        for ii in range(0,self.MAX_NUM_STREAMS):
            if(ii<len(self.telem_cfg)):
                widths.append(self.telem_cfg[ii].getStreamFifoSDataWidth())
            else:
                widths.append(0)
        return self.list_to_vhdl_str(widths)

    def stream_num_fifo_words_str(self):
        num_fifo_words=[]
        for ii in range(0,self.MAX_NUM_STREAMS):
            if(ii<len(self.telem_cfg)):
                num_fifo_words.append(self.telem_cfg[ii].getStreamNumFifoWords())
            else:
                num_fifo_words.append(0)
        return self.list_to_vhdl_str(num_fifo_words)

    def stream_field_bytes_str(self):
        bytes=[]
        for ii in range(0, self.MAX_NUM_STREAMS):
            for bb in range(0, self.MAX_NUM_FIELDS_PER_STREAM):
                if(ii<len(self.telem_cfg)):
                    if(bb<self.telem_cfg[ii].getStreamNumFields()):
                        bytes.append(self.telem_cfg[ii].fields[bb].bytes)
                    else:
                        bytes.append(0)
                else:
                    bytes.append(0)
        list_to_str = self.list_to_vhdl_str(bytes, self.MAX_NUM_FIELDS_PER_STREAM)
        return list_to_str;

    def stream_field_ids_str(telem_cfg):
        ids=[]
        for ii in range(0, self.MAX_NUM_STREAMS):
            for bb in range(0, self.MAX_NUM_FIELDS_PER_STREAM):
                if(ii<len(telem_cfg)):
                    if(bb<telem_cfg[ii].getStreamNumFields()):
                        ids.append("\""+telem_cfg[ii].fields[bb].id+"\"")
                    else:
                        ids.append("\"----\"")
                else:
                    ids.append("\"----\"")
        list_to_str = self.list_to_vhdl_str(ids, self.MAX_NUM_FIELDS_PER_STREAM)
        return list_to_str;

    def stream_fifo_addr_width_str(self):
        widths=[]
        for ii in range(0,self.MAX_NUM_STREAMS):
            if(ii<len(self.telem_cfg)):
                widths.append(self.telem_cfg[ii].getFifoAddrWidth())
            else:
                widths.append(self.STREAM_FIFO_ADDR_WIDTH)
        return self.list_to_vhdl_str(widths)

    def stream_fifo_data_width_str(self):
        widths=[]
        for ii in range(0,self.MAX_NUM_STREAMS):
            if(ii<len(self.telem_cfg)):
                widths.append(self.telem_cfg[ii].getFifoDataWidth())
            else:
                widths.append(self.STREAM_FIFO_DATA_WIDTH)
        return self.list_to_vhdl_str(widths)

  #  def stream_udp_len_str(self):
  #      lengths=[]
  #      for ii in range(0,self.MAX_NUM_STREAMS):
  #          if(ii<len(self.telem_cfg)):
  #              lengths.append(self.telem_cfg[ii].getUdpLength())
  #          else:
  #              lengths.append(self.MAX_PKT_UDP_DATA_SIZE_BYTES)
  #      return self.list_to_vhdl_str(lengths)

    def _gen_config_pkt_rom(self):
        """ Generate the config packet rom into byte ascii representation.  This format is for the vhdl pkg file.
            For config packet format, look at readmemd.
        """
        def append_ascii(string, l):
            temp=list(string)
            for ii in temp:
                l.append("{0:02x}".format(ord(ii)))
            return l
        def append_int(int_in, l, byte_len=1):
            assert(int_in<2**16),"append_int only supporting 2 byte int to list convesion"
            assert(byte_len in [1,2]), "append_int only supporting 1 or 2 byte len"
            assert(not(int_in>=2**8 and byte_len==1)), "append_int mismatch of input vs byte_len "+str(int_in)+" l="+str(l)
            msb_int=int(int_in/2**8) ##round down
            lsb_int=int_in-msb_int*2**8
            if(byte_len==2):
                l.append("{0:02x}".format(int(msb_int)))
            l.append("{0:02x}".format(int(lsb_int)))
            return l


        def get_block_len(stream):
            fields=len(stream.fields)
            length= 1 ##stream num
            length+= 2 ## length
            length+= self.STREAM_ID_SIZE_BYTES
            length+= 2 ## udp port
            length+= fields*(self.FIELD_ID_SIZE_BYTES+self.FIELD_LEN_SIZE_BYTES+self.FIELD_UNIT_TYPE_SIZE_BYTES)
            return length

        l=[]
        #append_help("BEEFD00D",l)
        append_int(int("0xBE",16),l)
        append_int(int("0xEF",16),l)
        append_int(int("0xD0",16),l)
        append_int(int("0x0D",16),l)
        append_int(int(self.TELEMETRY_VERSION),l)
        append_int(int(1),l) ## default number of config pkt fragments to 1, update later
        append_int(int(self.STREAM_ID_SIZE_BYTES),l)
        append_int(int(self.FIELD_ID_SIZE_BYTES),l)
        append_int(int(self.FIELD_UNIT_TYPE_SIZE_BYTES),l)

        #append 12 byte place holder for FPGA REV,DATE, and TIME
        for bb in range(0,12):
            append_int(0,l)

        for s in self.telem_cfg:
            ## first appen the stream number i.e. "01" for stream 1
            append_int(s.num,l)
            ## block length
            append_int(get_block_len(s),l,byte_len=2)
            ## udp port
            append_ascii(s.id,l)
            ## udp port
            append_int(self.PORT_DEST_STREAM_BASE+s.num,l,byte_len=2)
            for f in s.fields:
                append_ascii(f.id,l)
                append_int(int(f.bytes),l)
                append_ascii(f.units,l)
        cfg_length=len(l)

        #ascii_string = l.decode("ASCII")
       # print([chr(int(i, 16)) for i in l])
       # print(l)

       # print(" ")
        self.cfg_pkt_rom=l

    def _gen_config_pkt_lengths(self):
        """ After the rom has been generated, this method determines the number of config
            pkt fragments needed and the sizes of each.
        """
        cfg_rom_len=len(self.cfg_pkt_rom)

        # round up to get the total number of config pkts required
        self.cfg_num_pkts = math.ceil(cfg_rom_len / self.MAX_PKT_UDP_DATA_SIZE_BYTES)
        self.cfg_pkt_lengths = []
        for ii in range(0,self.cfg_num_pkts-1): # dont include last packet that is likely less than the max
            self.cfg_pkt_lengths.append(self.MAX_PKT_UDP_DATA_SIZE_BYTES)

        # now calc last packet and append that one
        remain_len = cfg_rom_len - ((self.cfg_num_pkts-1)*self.MAX_PKT_UDP_DATA_SIZE_BYTES)
        self.cfg_pkt_lengths.append(remain_len)

        # Update config packet rom to contain the correct number of config pkt fragments
        self.cfg_pkt_rom[5]="{0:02x}".format(int(self.cfg_num_pkts))


    def config_pkt_rom_vhdl(self):

        type
        s="    -- The ROM memory that holds the cfg packet payload\n\
        type t_cfg_rom     is array (0 to "+str(len(self.cfg_pkt_rom))+"-1) of std_logic_vector(7 downto 0);\n\
        constant CONFIG_PKT_ROM           : t_cfg_rom := ("
        rom_list_slv=[]
        for z in self.cfg_pkt_rom:
            rom_list_slv.append("x\""+z+"\"")
        s+=self.list_to_vhdl_str(rom_list_slv, 16)
        s+=");\n"

        return s


    def _gen_pkt_sizes(self):
        """ Determine our pkt sizes based on configuration and max UDP pkt size
        """ 
        pkt_sizes=[]
        ## payload status bytes consume some of the packet payload available
        for ii in range(0,self.ROUND_ROBIN_ITEMS):
            ## last pkt size(s) are the config packet(s)

            if(ii>=self.MAX_NUM_STREAMS):
                pkt_sizes.append(self.cfg_pkt_lengths[ii-self.MAX_NUM_STREAMS])

            elif(ii<len(self.telem_cfg)): ## active stream
                max_blk_space_avail = self.MAX_PKT_UDP_DATA_SIZE_BYTES - self.PAYLOAD_STATUS_SIZE_BYTES
                stream_total_bytes = self.telem_cfg[ii].getStreamTotalBytes()
                ## don't want to cut off a sample block in the packet so take the floor (round down)
                num_sa_blk_max = int(max_blk_space_avail/stream_total_bytes)

                min_calc = self.PAYLOAD_STATUS_SIZE_BYTES + stream_total_bytes 
                max_calc = self.PAYLOAD_STATUS_SIZE_BYTES + (stream_total_bytes * num_sa_blk_max)

                pkt_size = self.telem_cfg[ii].pkt_size 
                #self.PAYLOAD_STATUS_SIZE_BYTES
                #self.MAX_PKT_UDP_DATA_SIZE_BYTES
                stream_total_bytes = self.telem_cfg[ii].getStreamTotalBytes()
                if(pkt_size == "min"):
                    pkt_sizes.append(min_calc)
                elif(pkt_size =="max"):
                    pkt_sizes.append(max_calc)
                else:
                    try:
                        pkt_size_int = int(pkt_size)
                    except:
                        raise ValueError(f"Unsupported pkt_size {pkt_size} should be min, max, or integer string")
                    if(pkt_size_int < stream_total_bytes):
                        pkt_sizes.append(min_calc)
                    elif(pkt_size_int>max_blk_space_avail):
                        raise ValueError(f"Unsupported pkt_size {pkt_size} too large for bytes can't be larger than {max_blk_space_avail} bytes")
                    else: ## custom pkt size
                        num_sa_blks = int(pkt_size_int/stream_total_bytes) ## round number of blocks
                        pkt_size_custom = self.PAYLOAD_STATUS_SIZE_BYTES + (num_sa_blks * stream_total_bytes) ## total payload
                        pkt_sizes.append(pkt_size_custom)
                        print(f"Custom pkt size {pkt_size_int} resulted in pkt with number of sample blocks of {num_sa_blks} for a total payload (with header) of {pkt_size_custom}")


            else:
                ## not an active stream so fill that pkt size with 0
                pkt_sizes.append(0)
        self.pkt_sizes=pkt_sizes
        print("pkt_sizes=",self.pkt_sizes)

    def _gen_fifo_thresholds(self):
        """ Determine the FIFO thresholds that need to be set to indicate enough
            stream data has been captured to generate a packet.
        """            
        fifo_thresholds=[]
        ## payload status bytes consume some of the packet payload available
        for ii in range(0,self.ROUND_ROBIN_ITEMS):

            if(ii<len(self.telem_cfg)): ## active stream OR config packet which is upper stream
                bytes_per_fifo_entry = int((self.telem_cfg[ii].getFifoDataWidth()) / 8)
                payload_bytes_for_pkt = self.pkt_sizes[ii] - self.PAYLOAD_STATUS_SIZE_BYTES
                fifo_threshold = int(round((payload_bytes_for_pkt / bytes_per_fifo_entry),0))
                fifo_thresholds.append(fifo_threshold)
            elif(ii>=self.MAX_NUM_STREAMS): ## CONFIG pkt is highest stream number, don't include a threshold for config pkt
                pass
            else:
                fifo_thresholds.append(0) ## unused stream
        self.fifo_thresholds = fifo_thresholds
        print("fifo_thresholds=",self.fifo_thresholds)

    def pkt_sizes_vhdl(self):
        s="    type t_pkt_sizes is array (0 to ROUND_ROBIN_ITEMS-1) of integer; -- each stream plus 1 or more cfg pkts\n"
        s+="    constant PktPayloadSizeBytes : t_pkt_sizes := ("+self.list_to_vhdl_str(self.pkt_sizes)+");\n"
        return s


    def make_cfg_pkg(self, vhdl_pkg_file="telemetry_cfg_pkg.vhd"):

        f = open(vhdl_pkg_file,"w")

        f.write('-----------------------------------------\n')
        f.write('\
-- Auto-generated Telemetry Configuration Package from telem_cfg_csv_to_pkg.py\n\
--   \n\
----------------------------------------\n\
\n\
library ieee;\n\
use ieee.std_logic_1164.all;\n\
use ieee.std_logic_unsigned.all;\n\
use ieee.numeric_std.all;\n\
\n\
package telemetry_cfg_pkg is\n\
\n')
        f.write('\
    type t_stream_ints is array (0 to '+str(self.MAX_NUM_STREAMS-1)+') of natural;\n\
    type t_stream_bool is array (0 to '+str(self.MAX_NUM_STREAMS-1)+') of boolean;\n\
\n\
    constant TELEMETRY_VERSION           : std_logic_vector(7 downto 0) := std_logic_vector(to_unsigned('+str(self.TELEMETRY_VERSION)+',8));\n\
    constant PORT_DEST_STREAM_BASE       : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned('+str(self.PORT_DEST_STREAM_BASE)+',16));\n\
    constant PORT_DEST_CONFIG            : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned('+str(self.PORT_DEST_CONFIG)+',16));\n\
    constant FIELD_ENABLE_SIZE_BYTES     : natural := '+str(self.FIELD_ENABLE_SIZE_BYTES)+';\n\
    constant MAX_NUM_FIELDS_PER_STREAM   : natural := '+str(self.MAX_NUM_FIELDS_PER_STREAM)+';\n\
    constant MAX_NUM_STREAMS             : natural := '+str(self.MAX_NUM_STREAMS)+';\n\
    constant ROUND_ROBIN_ITEMS           : natural := '+str(self.ROUND_ROBIN_ITEMS)+';\n\
    constant STREAM_MAX_BYTES            : natural := '+str(self.STREAM_MAX_BYTES)+';\n\
    constant TIMESTAMP_SIZE_BYTES        : natural := '+str(self.TIMESTAMP_SIZE_BYTES)+';\n\
    constant PAYLOAD_STATUS_SIZE_BYTES   : natural := '+str(self.PAYLOAD_STATUS_SIZE_BYTES)+';\n\
    constant STREAM_USER_ERROR_BITS      : natural := '+str(self.STREAM_USER_ERROR_BITS)+';\n\
\n\
    constant getStreamNumFields          : t_stream_ints := ('+self.stream_lengths_str()+');\n\
    constant getStreamTotalBytes         : t_stream_ints := ('+self.stream_total_bytes_str()+');\n\
    -- use SLeft for indexing a stream data input e.g. stream_data(sleft(STREAM_ID_O) donwto 0) <= data;\n\
    constant SLeft                       : t_stream_ints := ('+self.stream_total_bits_left_str()+');\n\
    constant getStreamNumFifoWords       : t_stream_ints := ('+self.stream_num_fifo_words_str()+');\n\
    constant getStreamFifoDepthThreshold : t_stream_ints := ('+self.list_to_vhdl_str(self.fifo_thresholds)+');\n\
    constant getNumActiveStreams         : natural := '+str(len(self.telem_cfg))+';\n\
    constant getFifoAddrWidths           : t_stream_ints := ('+self.stream_fifo_addr_width_str()+');\n\
    constant getFifoDataWidths           : t_stream_ints := ('+self.stream_fifo_data_width_str()+');\n\
    constant getStreamFifoSDataWidth     : t_stream_ints := ('+self.stream_sdata_width_str()+');\n\
\n')

        f.write(self.pkt_sizes_vhdl()+'\n')

        f.write("\
    type t_stream_clks       is array (0 to MAX_NUM_STREAMS-1) of std_logic;\n\
    type t_stream_valids     is array (0 to MAX_NUM_STREAMS-1) of std_logic;\n\
    type t_stream_enables    is array (0 to MAX_NUM_STREAMS-1) of std_logic_vector(FIELD_ENABLE_SIZE_BYTES*8-1 downto 0);\n\
    type t_stream_data       is array (0 to MAX_NUM_STREAMS-1) of std_logic_vector(STREAM_MAX_BYTES*8-1 downto 0);\n\
    type t_stream_ts         is array (0 to MAX_NUM_STREAMS-1) of std_logic_vector(TIMESTAMP_SIZE_BYTES*8-1 downto 0);\n\
    type t_stream_user_error is array (0 to MAX_NUM_STREAMS-1) of std_logic_vector(STREAM_USER_ERROR_BITS-1 downto 0);\n\
\n\
    constant stream_data_init       :  t_stream_data    := (others => (others => '0'));\n\
    constant stream_valids_init     :  t_stream_valids  := (others => '0');\n\
    constant stream_clks_init       :  t_stream_clks    := (others => '0');\n\
    constant stream_enables_init    :  t_stream_enables := (others => (others=>'0'));\n\
    constant stream_user_error_init :  t_stream_user_error := (others => (others=>'0'));\n\
    constant stream_ts_init         :  t_stream_ts      := (others => (others=>'0'));\n\
\n")

        f.write("\
    -- Stream ID constants that can be used to index stream_data, stream_valids, and stream_clks in rtl interface.\n"
        )
        for s in self.telem_cfg:
            f.write("\
    constant S_"+s.id+" : natural := "+str(s.num)+";\n")
        f.write("\n")
        f.write(self.config_pkt_rom_vhdl()+'\n')

        f.write("\n")

        f.write('\
end telemetry_cfg_pkg;\n\
\n\
package body telemetry_cfg_pkg is\n\
end telemetry_cfg_pkg;\n\
')
        f.close()


if __name__ == "__main__":

    ## defaults
    csv_filename="telemetry_cfg.csv"
    vhdl_out_filename="telemetry_cfg_pkg.vhd"

    ## check for arguments -i and -o
    num_args = len(sys.argv)-1
    #assert(num_args==2),"Number of arguments incorrect, expected 2 input csv file and output vhdl file"
    if(num_args>0):
        csv_filename=sys.argv[1]
        vhdl_out_filename=sys.argv[2]
    print("argument csv_filename set to ",csv_filename)
    print("argument vhdl_out_filename set to ",vhdl_out_filename)
        #arg=sys.argv[a]
        #if(arg[0:2]=="-i"):
        #    csv_filename=arg[2:].strip()
        #    print("-i argument csv_filename set to ",csv_filename)
        #elif(arg[0:2]=="-o"):
        #    vhdl_out_filename=arg[2:].strip()
        #    print("-o argument vhdl_out_filename set to ",vhdl_out_filename)
        #else:
        #    assert(False),'unknown argument: '+str(arg)

    inst=telem_cfg_csv_to_pkg()
    inst.telem_csv_cfg_parse(csv_filename)
    inst.make_cfg_pkg(vhdl_out_filename)
