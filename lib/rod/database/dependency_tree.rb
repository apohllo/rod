module Rod
  module Database
    # The DependencyTree class represents the dependency
    # between the resources that are stored in a particular
    # database in terms of parent/child relationship
    # (super/sub class). It is build out of the database
    # meta-data and allows for querying for the parent resource
    # and children resources.
    class DependencyTree
      # Initialize the dependency tree with the +metadata+.
      # The meta-data is used to compute the dependency tree.
      def initialize(metadata)
        @parent = {}
        @children = Hash.new{|h,e| h[e] = []}
        metadata.resources.each do |resource,data|
          @parent[resource] = data.parent
          @children[data.parent] << resource
        end
      end

      # Returns the name of the parent resource for the
      # resource with given +name+.
      def parent(name)
        @parent[name]
      end

      # Returns the names of all child resources for the
      # resource with given +name+.
      def children(name)
        @children[name]
      end

      # Returns the resource names sorted in the topological order.
      def sorted
        return @sorted if defined?(@sorted)
        @sorted = []
        queue = self.roots
        begin
          resource = queue.shift
          @sorted << resource
          queue.concat(children(resource) || [])
        end until queue.empty?
        @sorted
      end

      # Returns the roots (the resources that do not have
      # their parents in the depenency tree) of the dependency
      # tree. Since the model is no longer based on
      # class inheritence there might be many roots. Their order
      # is undefined.
      def roots
        @parent.keys.select{|p| root?(p) }
      end

      # Return true if the resouce with the given +name+ is a root resource
      # (a resource whose parent is not persisted within given DB).
      def root?(name)
        present?(name) && !present?(parent(name))
      end

      # Returns true if the resource with the +name+ is present in the
      # dependency tree.
      def present?(name)
        !!@parent[name]
      end
    end
  end
end
