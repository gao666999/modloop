#!/bin/sh
#$ -S /bin/sh
#$ -cwd
#$ -o output.error
#$ -e output.error
#$ -j y
#####$ -l cpu600
#$ -l i386=true
#$ -l scratch=1G
#$ -r y
#$ -N loop
#$ -p -4
#$ -t 1-iteration
#####node limitation
#####$ -l modloop

input="${SGE_TASK_ID}.py"

# Create local scratch directory
tmpdir="/scratch/modloop/$JOB_ID/$SGE_TASK_ID"
mkdir -p $tmpdir
cd $tmpdir

# Get input files
cp DIR/$input DIR/pdb*AF*pdb .

/diva1/home/modeller/mod9v1 $input

# Copy back outputs
cp *.B* *.log DIR

rm -rf $tmpdir
