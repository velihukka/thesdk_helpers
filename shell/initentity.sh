#!/bin/sh
#############################################################################
# This is a templete generator for TheSDK entities. 
# It will genarate a template directory structure for a Entity
# including functional buffer models for matlab and python
# 
# Created by Marko Kosunen on 01.09.2017
#############################################################################
##Function to display help with -h argument and to control 
##The configuration from the command line
help_f()
{
cat << EOF
 INITENTITY Release 1.1 (06.09.2018)
 Templete generator for TheSDK entities
 Written by Marko Pikkis Kosunen
 -n
 SYNOPSIS
   initentity [OPTIONS] [ENTITY]
 DESCRIPTION
   Produces template directory structure for a Entity
 -n
 OPTIONS
   -G
       Add generated template files to current git branch.
       Does not commit.
   -h
       Show this help.
EOF
}

gitadd()
{
    CFILE=$1
    GA=$2
    if [ "${GA}" == "1" ]; then
        echo "Adding ${CFILE} to git"    
        git add  ${CFILE}    
    fi
}

GITADD="0"
while getopts Gh opt
do
  case "$opt" in
    G) GITADD="1";;
    h) help_f; exit 0;;
    \?) help_f; exit 0;;
  esac
  shift
done

#The name of the entity
NAME=$1
FNAME=`basename "$NAME"`
if [ ! -d "$NAME" ]; then
    for i in "$NAME" "$NAME/@${FNAME}" \
        "$NAME/Simulations" "$NAME/Simulations/rtlsim" \
        "$NAME/Simulations/rtlsim/work" "$NAME/vhdl" "$NAME/sv" \
        "$NAME/$FNAME" ; do
        #echo $i    
        mkdir $i
    done
    for i in $NAME/@${FNAME}/${FNAME}.m $NAME/vhdl/${FNAME}.vhd  $NAME/vhdl/tb_${FNAME}.vhd \
        $NAME/sv/${FNAME}.sv  $NAME/sv/tb_${FNAME}.sv $NAME/${FNAME}/__init__.py ; do
        touch $i
    done
else
    echo "Simulation exists!!"
    exit 0
fi

#cp $TEMPLATEDIR/configure $NAME
#Here are the template generatos
CURRENTFILE="$NAME/${FNAME}/__init__.py"
echo "Creating ${CURRENTFILE}"
cat <<EOF > ${CURRENTFILE}
# ${NAME} class 
# Last modification by initentity generator 
#Simple buffer template

import os
import sys
import numpy as np
import tempfile

from thesdk import *
from verilog import *
from vhdl import *

class ${NAME}(verilog,vhdl,thesdk):
    #Classfile is required by verilog and vhdl classes to determine paths.
    @property
    def _classfile(self):
        return os.path.dirname(os.path.realpath(__file__)) + "/"+__name__

    def __init__(self,*arg): 
        self.proplist = [ 'Rs' ];    # Properties that can be propagated from parent
        self.Rs =  100e6;            # Sampling frequency
        self.iptr_A = IO();          # Pointer for input data
        self.model='py';             # Can be set externally, but is not propagated
        self.par= False              # By default, no parallel processing
        self.queue= []               # By default, no parallel processing
        self._Z = IO();              # Pointer for output data
        if len(arg)>=1:
            parent=arg[0]
            self.copy_propval(parent,self.proplist)
            self.parent =parent;
        self.init()

    def init(self):
        #This gets updated every time you add an iofile
        self.iofile_bundle=Bundle()
        # Define the outputfile

        # Adds an entry named self._iofile_Bundle.Members['Z']
        if self.model=='sv':
            a=verilog_iofile(self,name='Z')
            a.simparam='-g g_outfile='+a.file
            b=verilog_iofile(self,name='A')
            b.simparam='-g g_infile='+b.file
            self.vlogparameters =dict([('g_Rs',self.Rs)])
        if self.model=='vhdl':
            a=vhdl_iofile(self,name='Z')
            a.simparam='-g g_outfile='+a.file
            b=vhdl_iofile(self,name='A')
            b.simparam='-g g_infile='+b.file
            self.vhdlparameters =dict([('g_Rs',self.Rs)])

    def main(self):
        out=self.iptr_A.Data
        if self.par:
            self.queue.put(out)
        self._Z.Data=out

    def run(self,*arg):
        if len(arg)>0:
            self.par=True      #flag for parallel processing
            self.queue=arg[0]  #multiprocessing.queue as the first argument
        if self.model=='py':
            self.main()
        else: 
          self.write_infile()

          if self.model=='sv':
              self.run_verilog()

          elif self.model=='vhdl':
              self.run_vhdl()

          self.read_outfile()

    def write_infile(self):
        self.iofile_bundle.Members['A'].data=self.iptr_A.Data.reshape(-1,1)
        self.iofile_bundle.Members['A'].write()

    def read_outfile(self):
        #a is just a shorthand notation
        a=self.iofile_bundle.Members['Z']
        a.read(dtype='object')
        out=a.data.astype('int')

        #This is for parallel processing
        if self.par:
            self.queue.put(out)
        self._Z.Data=out
        del self.iofile_bundle #Large files should be deleted

if __name__=="__main__":
    import matplotlib.pyplot as plt
    from  ${NAME} import *
    t=thesdk()
    t.print_log(type='I', msg="This is a testing template. Enjoy")
EOF
gitadd ${CURRENTFILE} ${GITADD}

CURRENTFILE="$NAME/@${FNAME}/${FNAME}.m"
echo "Creating ${CURRENTFILE}"
cat <<EOF > ${CURRENTFILE}
% ${NAME} class 
% Last modification by Marko Kosunen, marko.kosunen@aalto.fi, 24.08.2017 15:02
classdef inverter <  rtl & thesdk & handle
    properties (SetAccess = public)
        %Default values required at this hierarchy level or below.
        parent ;
        proplist = { 'Rs' };    %properties that can be propagated from parent
        Rs = 100e6;             % sampling frequency
        iptr_A
        model='matlab'
    end
    properties ( Dependent )
        classfile
    end
    properties ( Dependent)
        rtlcmd
    end
    properties ( SetAccess = protected )
        name
        entitypath  
        rtlsrcpath  
        rtlsimpath  
        workpath    
        infile
        outfile
    end
    properties (SetAccess = private )
        Z
    end
    methods
        function classfile=get.classfile(obj); classfile=mfilename('fullpath'); end;

        function rtlcmd = get.rtlcmd(obj); 
            %the could be gathered to rtl class in some way but they are now here for clarity
            submission = [' bsub -q normal ' ]; 
            rtllibcmd = [ 'vlib '  obj.workpath ' && sleep 2' ];
            rtllibmapcmd = [ 'vmap work '  obj.workpath ];

            if strcmp(obj.model,'vhdl')==1
                rtlcompcmd = [ 'vcom ' obj.rtlsrcpath '/' obj.name '.vhd ' ...
                    obj.rtlsrcpath '/tb_' obj.name '.vhd'];
                rtlsimcmd = ['vsim -64 -batch -t 1ps -g g_infile=' ...
                    char(obj.infile) ' -g g_outfile=' char(obj.outfile) ...
                    ' work.tb_' obj.name ' -do "run -all; quit -f;"'];

            elseif strcmp(obj.model,'sv')==1
                rtlcompcmd = [ 'vlog -work work '  obj.rtlsrcpath '/' obj.name '.sv '...
                    obj.rtlsrcpath '/tb_' obj.name '.sv'];
                rtlsimcmd = [ 'vsim -64 -batch -t 1ps -voptargs=+acc -g g_infile=' char(obj.infile) ...
                 ' -g g_outfile=' char(obj.outfile) ' work.tb_' obj.name  ' -do "run -all; quit;"' ];
            end
            rtlcmd = [ submission rtllibcmd   ' && ' rtllibmapcmd  ' && ' rtlcompcmd  ' && ' rtlsimcmd ];
        end;
        
        function obj = ${NAME}(varargin)
            if nargin>=1;
                parent=varargin{1}; 
                %Properties to copy from the parent
                obj.copy_propval(parent,obj.proplist);
                obj.parent=parent;
            end
            obj.init;
        end
        function obj = init(obj)
            obj.def_rtl;
            [ PATH, rndpart, EXT]=fileparts(tempname);
            obj.infile  = [ obj.rtlsimpath '/A_' rndpart '.txt' ];
            [ PATH, rndpart, EXT]=fileparts(tempname);
            obj.outfile = [ obj.rtlsimpath '/Z_' rndpart '.txt' ];
        end
        function obj=run(obj);
            if strcmp(obj.model,'matlab')
                obj.Z=obj.iptr_A.Value;
            elseif ~strcmp(obj.model,'matlab')
              l=length(obj.iptr_A.Value);
              delete(obj.infile);
              fid=fopen(obj.infile,'w');
              for i=1:l
                  fprintf(fid,'%d\n',obj.iptr_A.Value(i));
              end
              fclose(fid);
              delete(obj.outfile)
              system(obj.rtlcmd);
              fid=fopen(obj.outfile,'r');
              out = textscan(fid, '%d\n');
              fclose(fid);
              obj.Z=cell2mat(out).';
              delete(obj.infile)
              delete(obj.outfile)
            end
        end
    end
end
EOF
gitadd ${CURRENTFILE} ${GITADD}

CURRENTFILE="$NAME/vhdl/${FNAME}.vhd"
echo "Creating ${CURRENTFILE}"
cat <<EOF > ${CURRENTFILE}
-- This is ${NAME} VHDL model
-- Generated by initentity script
LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;
USE std.textio.all;


ENTITY ${NAME} IS
    PORT( A : IN  STD_LOGIC;
          Z : OUT STD_LOGIC
        );
END ${NAME};

ARCHITECTURE rtl OF ${NAME} IS
BEGIN
    buf:PROCESS(A)
    BEGIN
        Z<=A;
    END PROCESS;
END ARCHITECTURE;
EOF
gitadd ${CURRENTFILE} ${GITADD}

CURRENTFILE="$NAME/vhdl/tb_${FNAME}.vhd"
echo "Creating ${CURRENTFILE}"
cat <<EOF > ${CURRENTFILE}
-- This is testbench ${NAME} VHDL model
-- Generated by initentity script
LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;
USE std.textio.all;

ENTITY tb_${NAME} IS
    GENERIC(g_Rs     : real := 1.0e9;
            g_infile : STRING:="A.txt";
            g_outfile: STRING:="Z.txt"

           ); 
END ENTITY;

ARCHITECTURE behav OF tb_${FNAME} IS

FILE f_infile  : text open read_mode  is g_infile; 
FILE f_outfile : text open write_mode is g_outfile;

--These are to synchronize operation and end the simulation properly
SIGNAL s_clk : STD_LOGIC:='0';
SIGNAL s_EOF: BOOLEAN:=FALSE;
SIGNAL s_done: BOOLEAN:=FALSE;

--Design signals
CONSTANT c_tsample: time := real(1.0e12/g_Rs)*1 ps;    
SIGNAL s_A   : STD_LOGIC;
SIGNAL s_z   : STD_LOGIC;


BEGIN
clkgen:PROCESS
    BEGIN
        WHILE (NOT s_done) LOOP
            s_clk<=NOT s_clk;
            WAIT FOR  c_tsample/2;
        END LOOP;
        WAIT;
END PROCESS;

reader:PROCESS(s_clk)
    VARIABLE v_inline  : LINE;
    VARIABLE v_dataread: BIT_VECTOR(0 DOWNTO 0);
    VARIABLE v_A       : STD_LOGIC_VECTOR(0 DOWNTO 0);
    BEGIN
        IF  (NOT s_EOF) THEN
          IF rising_edge(s_clk) THEN
              readline(f_infile, v_inline); 
              read( v_inline , v_dataread);
              v_A:=to_stdlogicvector(v_dataread);
              s_A<=v_A(0);
          END IF;
      END IF;
      IF (endfile(f_infile)) THEN
          s_EOF<=TRUE;
      END IF;
END PROCESS;

writer:PROCESS(s_clk)
    VARIABLE v_outline  : LINE;
    VARIABLE v_datawrite: BIT;
    BEGIN
        v_datawrite:=to_bit(std_ulogic(s_Z));
    IF  (NOT s_done) THEN
      IF falling_edge(s_clk) THEN
          write( v_outline , v_datawrite);
          writeline(f_outfile, v_outline); 
          IF (s_EOF) THEN
              s_done<=TRUE;
          END IF;
      END IF;
  END IF;
END PROCESS;


DUT: ENTITY work.${NAME}(rtl)
    PORT MAP (A => s_A,
              Z => s_Z
             );
        
END ARCHITECTURE;

EOF
gitadd ${CURRENTFILE} ${GITADD}

CURRENTFILE="$NAME/sv/${FNAME}.sv"
echo "Creating ${CURRENTFILE}"
cat <<EOF > ${CURRENTFILE}
// This is ${NAME} verilog model
// Generated by initentity script
module ${NAME}( input A, output Z);

assign Z= A;

endmodule
EOF
gitadd ${CURRENTFILE} ${GITADD}

CURRENTFILE="$NAME/sv/tb_${FNAME}.sv"
echo "Creating ${CURRENTFILE}"
cat <<EOF > ${CURRENTFILE}
// This is testbench ${NAME} verilog model
// Generated by initentity script
module tb_${NAME} #( parameter g_infile  = "./A.txt",
                    parameter g_outfile = "./Z.txt",
                    parameter g_Rs      = 100.0e6
                  );
parameter c_Ts=1/(g_Rs*1e-12);


reg iptr_A;
reg clk;

wire Z;
integer StatusI, StatusO, infile, outfile;

initial clk = 1'b0;
always #(c_Ts)clk = !clk ;

${NAME} DUT( .A(iptr_A), .Z(Z) );

initial #0 begin
    infile = \$fopen(g_infile,"r"); // For reading
    outfile = \$fopen(g_outfile,"w"); // For writing
    while (!\$feof(infile)) begin
            @(posedge clk) StatusI=\$fscanf(infile,"%b\n",iptr_A);
            @(negedge clk) \$fwrite(outfile,"%b\n",Z);
    end
    \$finish;
end
endmodule
EOF
gitadd ${CURRENTFILE} ${GITADD}

exit


