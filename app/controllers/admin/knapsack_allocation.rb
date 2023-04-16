=begin

This class does a knapsack allocation using the per-dollar approach;
Each dollar of each project is regarded as a candidate. The candidates with
the most votes get selected.
(See https://web.stanford.edu/~anilesh/publications/knapsack_voting_full.pdf)

For example, suppose there are 3 projects: P1, P2, P3. The total budget is $10.
There are 3 voters: A, B, C. Their preferred allocations are
     A   B   C
P1: $4  $3  $0
P2: $5  $5  $0
P3: $1  $2 $10

Therefore, the votes per dollar for each project are
P1: 2 2 2 1 0 0 0 0 0 0
P2: 2 2 2 2 2 0 0 0 0 0
P3: 3 2 1 1 1 1 1 1 1 1

Since the budget is $10, the candidates (the dollars) who win are
P1: 2 2 2
P2: 2 2 2 2 2
P3: 3 2

Hence, the allocation (P1, P2, P3) = ($3, $5, $2).

Note that
- all the 10 candidates who get at least 2 votes win
- all the 9 candidates who get only 1 vote lose
- all the other candidates who got 0 votes lose

Since the budget is $10, we can allocate it nicely. Now, suppose that the
budget is $13. Then there is a residual budget of $3. Since there are
9 candidates who should get this money, we have to do a partial allocation.
There are two ways to do partial allocations:
- Fractional partial allocation: In this case, we divide the $3 equally
  among the 9 candidates who get 1 vote. Thus, (P1, P2, P3) =
  ($3 + ($3 * 1/9), $5, $2 + ($3 * 8/9)).
- Increasing partial allocation: We give the residual budget to the projects
  that need the least amount of the residual budget first. In this case,
  P1 needs $1 and P2 needs $8. Thus, (P1, P2, P3) = ($3 + $1, $5, $2 + $2).

USAGE
-----

The class takes the |project_costs| and |budget|, and does a knapsack allocation.
|project_costs| should be a Hash, where the keys are project IDs, and the
values are the lists of the amounts that have been allocated by voters to this project.
Zero amounts don't need to be reported but are harmless if reported.

It also optionally takes a |partial_allocation_method| function to allocate
money to projects once there is a tie among several project_chunks. The default
allocates in increasing order of chunk sizes.

After creating an instance, the total allocation can be accessed using the method
total_allocations.

Example:
  project_costs = {
    P1: [4, 3, 0],
    P2: [5, 5, 0],
    P3: [1, 2, 10]
  }
  budget = 10
  allocation = KnapsackAllocation.new(project_costs, budget)
  puts allocation.total_allocations  # {P1: 3, P2: 5, P3: 2}

=end

module Admin
  class KnapsackAllocation
    attr_reader :total_allocations

    # Other accessor methods
    attr_reader :discrete_allocations
    attr_reader :partial_allocations
    attr_reader :discrete_vote
    attr_reader :partial_project_ids

    # The main function that does all the computation
    def initialize(project_costs, budget, partial_allocation_method = KnapsackAllocation.method(:increasing_partial_allocation))

      # For any project, chunk it into discrete pieces such that each piece is the difference of two subsequent values that occur in the project_costs for that project. For each chunk, associate it with the number of users who voted for that chunk
      chunks = []
      project_costs.keys.each do |project_id|
        chunks += chunk_project_votes(project_costs[project_id], project_id)
      end

      # Now, transform it so that chunks are arranged by the number of votes received
      chunks = chunks
        .group_by { |vote| vote[2] }
        .sort { |x, y| y[0] <=> x[0] }

      # Now allocate funds to projects in decreasing order of votes received
      @discrete_allocations = Hash.new(0)
      @partial_allocations = Hash.new(0)
      @discrete_vote = 0
      @partial_project_ids = []
      accumulated_budget = 0
      i = 0
      n = chunks.length
      while i < n do
        next_chunks = chunks[i][1]
        next_cost = next_chunks.map { |chunk| chunk[1] }.sum
        if next_cost + accumulated_budget <= budget
          accumulated_budget += next_cost
          next_chunks.each { |chunk| @discrete_allocations[chunk[0]] += chunk[1] }
          @discrete_vote = chunks[i][0]
        else
          if accumulated_budget < budget
            partially_allocated_chunks = next_chunks.map{ |chunk| [chunk[0], chunk[1]] }
            partial_allocation_method.call(partially_allocated_chunks, budget-accumulated_budget, @discrete_allocations)
              .each{|x| @partial_allocations[x[0]] += x[1]}
            @partial_project_ids = next_chunks.map{ |chunk| chunk[0] }
          end
          break
        end
        i += 1
      end

      # Combine discrete allocations and partial allocations into total allocations
      @total_allocations = Hash.new(0)
      (@discrete_allocations.keys | @partial_allocations.keys).map do |project_id|
        @total_allocations[project_id] = @discrete_allocations[project_id] + @partial_allocations[project_id]
      end
    end

    def chunk_project_votes(costs, project_id)
      # |costs| is a list of all the chosen costs in the votes cast for this project
      # Returns project_chunks, a list, with each element being of the type [project_id, cost_chunk, votes]
      #
      # For example, suppose the voters' preferred allocations for P2 are $5, $5, $8, $10.
      # Then, the votes per dollar for P2 are 4 4 4 4 4 2 2 2 1 1.
      # Therefore, chunk_project_votes([5, 5, 8, 10], "P2") returns 
      # [
      #   ["P2", 5, 4],
      #   ["P2", 3, 2],
      #   ["P2", 2, 1]
      # ]
      prev = 0
      n = costs.length
      i = 0
      project_chunks = []
      costs.sort.each do |cost|
        if cost != prev
          chunk = cost - prev
          prev = cost
          project_chunks << [project_id, chunk, n - i]
        end
        i += 1
      end
      project_chunks
    end

    # A partial allocation method for residual budget where the projects are satisfied proportionally
    def self.fractional_partial_allocation(chunks, budget, _)
      cost = chunks.map {|chunk| chunk[1]}.sum
      fraction = budget.to_f / cost
      chunks.map { |chunk| [chunk[0], chunk[1] * fraction] }
    end

    # A partial allocation method for residual budget where the projects are satisfied in increasing cost
    def self.increasing_partial_allocation(chunks, budget, _)
      assigned_cost = 0
      chunks.sort { |x, y| x[1] <=> y[1] }.map do |chunk|
        if assigned_cost < budget
          cost = chunk[1]
          if cost > budget - assigned_cost
            cost = budget - assigned_cost
          end
          assigned_cost += cost
          [chunk[0], cost]
        end
      end.compact
    end

    # A partial allocation method for residual budget that allocates budget to projects that receive the lowest allocations first, i.e. trying to equalize the allocations.
    # Inspired by the maximum-entropy tie-breaking mechanism in the "Truthful Aggregation of Budget Proposals" paper by Freeman et al.
    def self.equalizing_partial_allocation(chunks, budget, discrete_allocations)
      events = []
      chunks.each do |chunk|
        project_id = chunk[0]
        current_allocation = discrete_allocations[project_id]
        events << [current_allocation, 0, project_id]
        events << [current_allocation + chunk[1], 1, project_id]
      end

      current_level = 0
      ps = []
      allocations = Hash.new(0)
      events.sort.each do |event|
        level, event_type, project_id = event
        if level != current_level and !ps.empty?
          level_diff = level - current_level
          if ps.length * level_diff >= budget
            tmp = budget.to_f / ps.length
            ps.each { |project_id| allocations[project_id] += tmp }
            break
          else
            ps.each { |project_id| allocations[project_id] += level_diff }
            budget -= ps.length * level_diff
          end
        end
        current_level = level
        if event_type == 0
          ps << project_id
        else
          ps.delete(project_id)
        end
      end
      allocations.to_a
    end
  end
end
